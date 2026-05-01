'use strict';

/**
 * farmController.js
 * Orchestrates the full AI Crop Advisory pipeline:
 *   1. Validate input
 *   2. Pincode → Location
 *   3. Location → Weather
 *   4. Build prompt
 *   5. Groq → Advisory text
 *   6. Persist to DB
 *   7. Return structured response
 */

const FarmRequest              = require('../models/FarmRequest');
const { getLocationFromPincode } = require('../services/pincodeService');
const { getWeather }           = require('../services/weatherService');
const { getCropAdvisory }      = require('../services/aiService');
const { buildCropAdvisoryPrompt } = require('../utils/promptBuilder');
const { streamPDF }            = require('../services/pdfService');

// ─── Validation helper ────────────────────────────────────────────────────────

const VALID_WATER  = ['low', 'medium', 'high'];
const VALID_SOIL   = ['alluvial', 'black', 'red', 'laterite', 'sandy', 'loamy', 'clay', 'other'];

function validateInput(body) {
  const errors = [];

  const land = parseFloat(body.land);
  if (isNaN(land) || land < 0.1 || land > 10000) {
    errors.push('"land" must be a number between 0.1 and 10000 (acres).');
  }

  if (!body.crop || typeof body.crop !== 'string' || body.crop.trim().length < 2) {
    errors.push('"crop" is required and must be at least 2 characters.');
  }

  const soil = (body.soil || '').toLowerCase().trim();
  if (!soil) {
    errors.push(`"soil" is required. Accepted values: ${VALID_SOIL.join(', ')}, or any other type.`);
  }

  const water = (body.water || '').toLowerCase().trim();
  if (!VALID_WATER.includes(water)) {
    errors.push(`"water" must be one of: ${VALID_WATER.join(', ')}.`);
  }

  if (!/^\d{6}$/.test(String(body.pincode || ''))) {
    errors.push('"pincode" must be exactly 6 digits.');
  }

  return errors;
}

// ─── Controller ───────────────────────────────────────────────────────────────

/**
 * POST /api/farm/analyze
 */
async function analyzeFarm(req, res) {
  const startTime = Date.now();

  // 1. Validate
  const errors = validateInput(req.body);
  if (errors.length > 0) {
    return res.status(400).json({ error: errors.join(' ') });
  }

  const farmInput = {
    land:    parseFloat(req.body.land),
    crop:    req.body.crop.trim().toLowerCase(),
    soil:    req.body.soil.trim().toLowerCase(),
    water:   req.body.water.trim().toLowerCase(),
    pincode: String(req.body.pincode).trim(),
  };

  let dbRecord = null;

  try {
    // 2. Pincode → Location
    let location;
    try {
      location = await getLocationFromPincode(farmInput.pincode);
    } catch (err) {
      return res.status(400).json({ error: `Invalid pincode: ${err.message}` });
    }

    // 3. Weather
    const weatherData = await getWeather(location.district);

    // 4. Build prompt
    const prompt = buildCropAdvisoryPrompt(farmInput, location, weatherData);

    // 5. AI Advisory
    let aiResponse;
    try {
      aiResponse = await getCropAdvisory(prompt);
    } catch (err) {
      // Partial save with error note
      await FarmRequest.create({
        ...farmInput,
        location,
        weatherSnapshot: weatherData.current,
        error: err.message,
        processingTimeMs: Date.now() - startTime,
      }).catch(() => {}); // DB write failure is non-fatal here
      return res.status(503).json({ error: `AI service error: ${err.message}` });
    }

    // 6. Persist
    dbRecord = await FarmRequest.create({
      ...farmInput,
      location,
      weatherSnapshot: {
        ...weatherData.current,
        forecast: weatherData.forecast,
      },
      aiResponse,
      processingTimeMs: Date.now() - startTime,
      userId: req.user?._id ?? null,
    });

    // 7. Respond
    return res.status(200).json({
      success: true,
      requestId: dbRecord._id,
      location: {
        pincode:        location.pincode,
        postOfficeName: location.postOfficeName,
        district:       location.district,
        state:          location.state,
      },
      weather: {
        current:  weatherData.current,
        forecast: weatherData.forecast,
      },
      plan:            aiResponse,
      processingTimeMs: Date.now() - startTime,
    });

  } catch (err) {
    console.error('[FarmController] Unhandled error:', err);
    return res.status(500).json({ error: 'Internal server error. Please try again.' });
  }
}

/**
 * GET /api/farm/history/:pincode
 * Returns recent advisories for a given pincode (useful for caching on client).
 */
async function getHistory(req, res) {
  const { pincode } = req.params;
  if (!/^\d{6}$/.test(pincode)) {
    return res.status(400).json({ error: 'Invalid pincode.' });
  }

  try {
    const records = await FarmRequest.find(
      { 'location.pincode': pincode, error: { $exists: false } },
      { aiResponse: 1, crop: 1, location: 1, createdAt: 1 }
    )
      .sort({ createdAt: -1 })
      .limit(10)
      .lean();

    return res.json({ count: records.length, records });
  } catch (err) {
    console.error('[FarmController] History error:', err);
    return res.status(500).json({ error: 'Could not fetch history.' });
  }
}

/**
 * POST /api/farm/download-pdf
 * Accepts the full advisory payload and streams a formatted PDF back.
 */
async function downloadPDF(req, res) {
  try {
    const { input, location, weather, plan } = req.body;

    // Basic presence check
    if (!plan || typeof plan !== 'string' || plan.trim().length < 10) {
      return res.status(400).json({ error: '"plan" text is required to generate PDF.' });
    }
    if (!input || !location) {
      return res.status(400).json({ error: '"input" and "location" fields are required.' });
    }

    console.log(`[FarmController] Generating PDF for ${input.crop} @ ${location.district}`);
    streamPDF({ input, location, weather: weather ?? {}, plan }, res);

  } catch (err) {
    console.error('[FarmController] PDF generation error:', err);
    // Only send JSON error if headers not yet sent
    if (!res.headersSent) {
      res.status(500).json({ error: 'Failed to generate PDF. Please try again.' });
    }
  }
}

module.exports = { analyzeFarm, getHistory, downloadPDF };
