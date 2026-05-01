'use strict';

/**
 * pincodeService.js
 * Resolves an Indian 6-digit pincode → { district, state } using
 * the free postalpincode.in API.
 *
 * Retry logic: up to MAX_RETRIES attempts with exponential back-off.
 */

const https = require('https');

const BASE_URL = (process.env.POSTAL_API_BASE_URL || 'https://api.postalpincode.in').replace(/\/$/, '');
const MAX_RETRIES = 2;
const RETRY_DELAY_MS = 500;

// ─── Tiny HTTP helper (no extra dep needed) ───────────────────────────────────

function httpGet(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`Invalid JSON from pincode API: ${e.message}`));
        }
      });
    }).on('error', reject);
  });
}

function delay(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

// ─── Main resolver ────────────────────────────────────────────────────────────

/**
 * @param {string} pincode  6-digit Indian pincode
 * @returns {{ district: string, state: string, postOfficeName: string }}
 * @throws  Error on invalid pincode or API failure
 */
async function getLocationFromPincode(pincode) {
  if (!/^\d{6}$/.test(String(pincode))) {
    throw new Error(`Invalid pincode format: "${pincode}". Must be exactly 6 digits.`);
  }

  let lastError;

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const url = `${BASE_URL}/pincode/${pincode}`;
      console.log(`[PincodeService] Attempt ${attempt + 1}: GET ${url}`);

      const json = await httpGet(url);

      // API returns an array; first element has Status and PostOffice[]
      if (!Array.isArray(json) || json.length === 0) {
        throw new Error('Unexpected response structure from pincode API.');
      }

      const result = json[0];

      if (result.Status !== 'Success') {
        throw new Error(
          `Pincode "${pincode}" not found. API message: ${result.Message || 'No records'}`
        );
      }

      const postOffices = result.PostOffice;
      if (!Array.isArray(postOffices) || postOffices.length === 0) {
        throw new Error(`No post offices found for pincode "${pincode}".`);
      }

      // Pick first post office entry
      const po = postOffices[0];

      const district = (po.District || po.Taluk || '').trim();
      const state = (po.State || '').trim();
      const postOfficeName = (po.Name || '').trim();

      if (!district || !state) {
        throw new Error(`Incomplete location data for pincode "${pincode}".`);
      }

      console.log(`[PincodeService] Resolved ${pincode} → ${district}, ${state}`);
      return { district, state, postOfficeName, pincode };

    } catch (err) {
      lastError = err;
      if (attempt < MAX_RETRIES) {
        const waitMs = RETRY_DELAY_MS * Math.pow(2, attempt);
        console.warn(`[PincodeService] Attempt ${attempt + 1} failed: ${err.message}. Retrying in ${waitMs}ms…`);
        await delay(waitMs);
      }
    }
  }

  throw new Error(`Pincode resolution failed after ${MAX_RETRIES + 1} attempts: ${lastError?.message}`);
}

module.exports = { getLocationFromPincode };
