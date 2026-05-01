'use strict';
/**
 * languageService.js
 * Detects the language of a text string using the `franc-min` library.
 *
 * franc-min uses ISO 639-3 trigram detection.
 * We map the result to the 2-letter code Groq understands and a display name.
 */

// franc-min is an ESM-only package from franc v6+.
// We use a dynamic import wrapped in a sync cache to stay compatible with CJS.
let _franc = null;

async function getFranc() {
  if (!_franc) {
    const mod = await import('franc-min');
    _franc = mod.franc;
  }
  return _franc;
}

// ─── ISO 639-3 → { code2: string, name: string } ────────────────────────────
const LANG_MAP = {
  // South Indian languages (high priority for KrishiMitra)
  tel: { code2: 'te', name: 'Telugu'  },
  kan: { code2: 'kn', name: 'Kannada' },
  tam: { code2: 'ta', name: 'Tamil'   },
  mal: { code2: 'ml', name: 'Malayalam' },
  // North Indian
  hin: { code2: 'hi', name: 'Hindi'   },
  mar: { code2: 'mr', name: 'Marathi' },
  pan: { code2: 'pa', name: 'Punjabi' },
  guj: { code2: 'gu', name: 'Gujarati' },
  ben: { code2: 'bn', name: 'Bengali' },
  urd: { code2: 'ur', name: 'Urdu'    },
  ory: { code2: 'or', name: 'Odia'    },
  // Global
  eng: { code2: 'en', name: 'English' },
};

const DEFAULT = { code2: 'en', name: 'English' };

// ─── Public API ───────────────────────────────────────────────────────────────
/**
 * Detects the language of `text`.
 * @param {string} text
 * @returns {Promise<{ code2: string, name: string }>}
 *   e.g. { code2: 'te', name: 'Telugu' }
 */
async function detectLanguage(text) {
  if (!text || text.trim().length < 5) return DEFAULT;

  try {
    const franc  = await getFranc();
    const iso639 = franc(text.trim());          // e.g. 'tel', 'hin', 'eng'
    return LANG_MAP[iso639] ?? DEFAULT;
  } catch (err) {
    console.warn('[LanguageService] Detection failed:', err.message);
    return DEFAULT;
  }
}

/**
 * Maps a CAMB.AI language string (BCP-47 / ISO 639-1) to our internal format.
 * Falls back to detectLanguage if the CAMB string is unrecognised.
 */
async function fromCambLanguage(cambLang, text) {
  if (!cambLang) return detectLanguage(text);

  const code2Lower = cambLang.toLowerCase().split('-')[0]; // 'te-IN' → 'te'

  // Find by code2
  const entry = Object.values(LANG_MAP).find(v => v.code2 === code2Lower);
  return entry ?? DEFAULT;
}

module.exports = { detectLanguage, fromCambLanguage };
