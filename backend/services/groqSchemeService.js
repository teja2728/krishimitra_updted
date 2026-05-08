const Groq = require('groq-sdk');
const Scheme = require('../models/Scheme');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

const FRESHNESS_DAYS = 7; // Re-fetch from Groq if data is older than this

// ─── Validation Layer ─────────────────────────────────────────────────────────

function isValidUrl(url) {
  try {
    const u = new URL(url);
    return u.protocol === 'http:' || u.protocol === 'https:';
  } catch {
    return false;
  }
}

function validateAndNormalize(raw) {
  if (!raw || typeof raw !== 'object') return null;

  const name = (raw.name || '').toString().trim();
  const description = (raw.description || '').toString().trim();
  if (!name || !description) return null; // Required fields

  const typeRaw = (raw.type || 'state').toString().toLowerCase();
  const type = typeRaw === 'central' ? 'central' : 'state';

  // Normalize: central schemes → state = "All"
  const state = type === 'central' ? 'All' : (raw.state || 'All').toString().trim();

  const confidence = parseFloat(raw.confidence ?? 0.8);
  if (isNaN(confidence) || confidence < 0.5) return null; // Reject low confidence

  const applyLink = isValidUrl(raw.applyLink || '') ? raw.applyLink : '';

  const benefits = Array.isArray(raw.benefits)
    ? raw.benefits.map(b => b.toString().trim()).filter(Boolean)
    : [];
  const eligibility = Array.isArray(raw.eligibility)
    ? raw.eligibility.map(e => e.toString().trim()).filter(Boolean)
    : typeof raw.eligibility === 'string' && raw.eligibility.trim()
      ? [raw.eligibility.trim()]
      : [];
  const documents = Array.isArray(raw.documents)
    ? raw.documents.map(d => d.toString().trim()).filter(Boolean)
    : [];

  const deadline = (raw.deadline || '').toString().trim();

  return {
    name,
    type,
    state,
    description,
    benefits,
    eligibility,
    documents,
    applyLink,
    deadline,
    category: (raw.category || '').toString().trim(),
    confidence,
    source: 'ai',
    isAiGenerated: true,
    approved: true,
    fetchedAt: new Date(),
    lastVerifiedAt: new Date(),
  };
}

// ─── Groq Fetch ───────────────────────────────────────────────────────────────

async function fetchSchemesFromGroq(profile) {
  const { state, crops = [], soilType = '', landSize = 0 } = profile;

  const prompt = `You are an expert on Indian government agricultural schemes.
Farmer profile:
- State: ${state}
- Crops: ${crops.join(', ') || 'General'}
- Soil Type: ${soilType || 'Not specified'}
- Land Size: ${landSize} acres

List 8-10 real Indian government schemes relevant to this farmer.
Include both central (national) and state-level schemes for ${state}.

Return ONLY a valid JSON array. No markdown, no explanation, no extra text.
Each object must have exactly these fields:
[
  {
    "name": "Scheme Name",
    "type": "central" or "state",
    "state": "${state}" (or "All" for central),
    "category": "subsidy|loan|insurance|machinery|irrigation|training",
    "description": "Clear 2-sentence description of what the scheme offers",
    "benefits": ["benefit 1", "benefit 2", "benefit 3"],
    "eligibility": ["criterion 1", "criterion 2"],
    "documents": ["Aadhaar Card", "Land Records", "Bank Account"],
    "applyLink": "https://valid-url.gov.in or empty string",
    "deadline": "YYYY-MM-DD or Open",
    "confidence": 0.85
  }
]`;

  const completion = await groq.chat.completions.create({
    model: 'llama-3.1-8b-instant', // speed + cost for scheme list fetching
    messages: [
      { role: 'system', content: 'You are a JSON-only responder. Output only a valid JSON array, nothing else.' },
      { role: 'user', content: prompt },
    ],
    temperature: 0.2,
    max_tokens: 3000,
  });

  const raw = completion.choices[0]?.message?.content?.trim() ?? '[]';
  // Strip accidental markdown fences
  const jsonStr = raw
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim();

  let parsed;
  try {
    parsed = JSON.parse(jsonStr);
  } catch (e) {
    console.error('[GroqSchemes] Failed to parse JSON:', e.message);
    return [];
  }

  if (!Array.isArray(parsed)) return [];
  return parsed;
}

// ─── DB-First Smart Fetch ─────────────────────────────────────────────────────

/**
 * Main entry point: DB-first, Groq fallback.
 * 1. Query MongoDB for state + central schemes
 * 2. If fresh & sufficient → return
 * 3. Else → Groq → validate → deduplicate → save → return
 */
async function getSmartSchemes(profile) {
  const { state } = profile;
  const stateEsc = (state || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const stateRegex = new RegExp(`^${stateEsc}$`, 'i');

  // 1. Query DB
  const dbSchemes = await Scheme.find({
    approved: true,
    $or: [
      { state: stateRegex },
      { state: 'All' },
      { type: 'central' },
    ],
  }).lean();

  // 2. Freshness check — use DB data only if we have BOTH:
  //    a) enough overall fresh schemes AND
  //    b) at least one scheme specifically matching the user's state
  //    (so a pure "central only" cache doesn't mask missing state schemes)
  const MIN_FRESH = 3;
  const MIN_STATE_SPECIFIC = 1;

  const freshnessCutoff = new Date(Date.now() - FRESHNESS_DAYS * 24 * 60 * 60 * 1000);
  const freshSchemes = dbSchemes.filter(
    s => !s.fetchedAt || new Date(s.fetchedAt) > freshnessCutoff
  );

  const hasEnoughFresh = freshSchemes.length >= MIN_FRESH;
  const hasStateSpecific = state
    ? freshSchemes.some(
        s => s.type === 'state' &&
             s.state && s.state.toLowerCase() === state.toLowerCase()
      )
    : true; // no state preference → central-only is fine

  if (hasEnoughFresh && hasStateSpecific) {
    console.log(`[GroqSchemes] DB hit: ${freshSchemes.length} fresh schemes for ${state}`);
    return { schemes: sortByState(freshSchemes, state), source: 'db' };
  }

  // 3. DB miss or stale → call Groq
  console.log(`[GroqSchemes] DB miss for ${state} — calling Groq...`);
  let rawSchemes;
  try {
    rawSchemes = await fetchSchemesFromGroq(profile);
  } catch (err) {
    console.error('[GroqSchemes] Groq error:', err.message);
    // Fallback to whatever is in DB
    if (dbSchemes.length > 0) {
      return { schemes: sortByState(dbSchemes, state), source: 'db_stale' };
    }
    throw new Error('No schemes available. Please try again later.');
  }

  // 4. Validate & normalize
  const validated = rawSchemes
    .map(validateAndNormalize)
    .filter(Boolean);

  console.log(`[GroqSchemes] Groq returned ${rawSchemes.length}, valid: ${validated.length}`);

  // 5. Save to DB (upsert — skip if name already exists)
  const saved = [];
  for (const scheme of validated) {
    try {
      const doc = await Scheme.findOneAndUpdate(
        { name: scheme.name },
        { $setOnInsert: scheme },
        { upsert: true, new: true, rawResult: false }
      );
      saved.push(doc);
    } catch (err) {
      // Duplicate key or validation error — skip
      if (err.code !== 11000) console.warn('[GroqSchemes] Save error:', err.message);
    }
  }

  // 6. Merge with existing DB schemes (de-duplicate by id)
  const allById = new Map();
  [...dbSchemes, ...saved].forEach(s => {
    const id = (s._id || s.id)?.toString();
    if (id) allById.set(id, s);
  });

  const final = sortByState([...allById.values()], state);
  return { schemes: final, source: 'groq' };
}

function sortByState(schemes, state) {
  return schemes.slice().sort((a, b) => {
    const aMatch = (a.state || '').toLowerCase() === (state || '').toLowerCase() ? 1 : 0;
    const bMatch = (b.state || '').toLowerCase() === (state || '').toLowerCase() ? 1 : 0;
    return bMatch - aMatch;
  });
}

module.exports = { getSmartSchemes };
