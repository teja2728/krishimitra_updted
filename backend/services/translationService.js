/**
 * translationService.js
 * Translates scheme content via Groq LLM.
 * ─ In-process LRU cache keyed by (schemeId + lang) prevents re-translating.
 * ─ Batch-translates only the text fields; leaves metadata (type, state, etc.) untouched.
 */
const Groq = require('groq-sdk');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// ─── Simple in-process LRU Cache ─────────────────────────────────────────────
const MAX_CACHE = 500;  // maximum entries kept
const _cache = new Map(); // key → translated payload

function _cacheKey(schemeId, lang) {
  return `${schemeId}::${lang}`;
}

function _cacheGet(schemeId, lang) {
  const k = _cacheKey(schemeId, lang);
  if (!_cache.has(k)) return null;
  // Move to end (LRU refresh)
  const v = _cache.get(k);
  _cache.delete(k);
  _cache.set(k, v);
  return v;
}

function _cacheSet(schemeId, lang, value) {
  const k = _cacheKey(schemeId, lang);
  if (_cache.size >= MAX_CACHE) {
    // Evict oldest entry
    const firstKey = _cache.keys().next().value;
    _cache.delete(firstKey);
  }
  _cache.set(k, value);
}

// ─── Language label map ───────────────────────────────────────────────────────
const LANG_LABELS = {
  te: 'Telugu',
  hi: 'Hindi',
  kn: 'Kannada',
  en: 'English',
};

// ─── Fields to translate ──────────────────────────────────────────────────────
function _extractTextFields(scheme) {
  return {
    name:        scheme.name        || '',
    description: scheme.description || '',
    benefits:    Array.isArray(scheme.benefits)    ? scheme.benefits    : [],
    eligibility: Array.isArray(scheme.eligibility) ? scheme.eligibility : [],
    documents:   Array.isArray(scheme.documents)   ? scheme.documents   : [],
    category:    scheme.category    || '',
  };
}

// ─── Translate a single scheme via Groq ──────────────────────────────────────
async function _translateSingle(scheme, langCode) {
  const id   = (scheme._id || scheme.id || '').toString();
  const lang = LANG_LABELS[langCode] || langCode;

  // Cache hit?
  const cached = _cacheGet(id, langCode);
  if (cached) return { ...scheme, ...cached };

  const textFields = _extractTextFields(scheme);

  const prompt = `You are a government-scheme translation assistant.
Translate the following JSON from English to ${lang}.

Rules:
- Keep ALL JSON keys EXACTLY as-is (do not translate keys)
- Only translate the string VALUES
- For arrays, translate each string element
- Return ONLY valid JSON, no explanation, no markdown
- Preserve proper nouns (e.g. "PM-Kisan", "Aadhaar") as-is

Data to translate:
${JSON.stringify(textFields, null, 2)}`;

  const completion = await groq.chat.completions.create({
    model: 'llama-3.3-70b-versatile',
    messages: [
      { role: 'system', content: 'You are a JSON-only translation assistant. Output ONLY valid JSON.' },
      { role: 'user', content: prompt },
    ],
    temperature: 0.1,
    max_tokens: 1500,
  });

  const raw = (completion.choices[0]?.message?.content || '{}').trim();
  const jsonStr = raw
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim();

  let translated;
  try {
    translated = JSON.parse(jsonStr);
  } catch (e) {
    console.warn(`[Translation] JSON parse failed for scheme "${scheme.name}" (${langCode}):`, e.message);
    return scheme; // fallback: return untranslated
  }

  // Merge translated fields back
  const merged = {
    name:        translated.name        || scheme.name,
    description: translated.description || scheme.description,
    benefits:    Array.isArray(translated.benefits)    ? translated.benefits    : scheme.benefits,
    eligibility: Array.isArray(translated.eligibility) ? translated.eligibility : scheme.eligibility,
    documents:   Array.isArray(translated.documents)   ? translated.documents   : scheme.documents,
    category:    translated.category    || scheme.category,
  };

  _cacheSet(id, langCode, merged);
  return { ...scheme, ...merged };
}

// ─── Public API: translate array of schemes ───────────────────────────────────
/**
 * Translates an array of scheme objects into the target language.
 * Falls back to English gracefully on any per-scheme failure.
 * @param {Object[]} schemes
 * @param {string}   langCode  e.g. 'te', 'hi', 'kn'
 * @returns {Promise<Object[]>}
 */
async function translateSchemes(schemes, langCode) {
  if (!langCode || langCode === 'en') return schemes;
  if (!LANG_LABELS[langCode]) {
    console.warn(`[Translation] Unknown language code "${langCode}", skipping.`);
    return schemes;
  }

  // Translate concurrently (but cap at 5 parallel requests to avoid rate limits)
  const BATCH = 5;
  const results = [];
  for (let i = 0; i < schemes.length; i += BATCH) {
    const batch = schemes.slice(i, i + BATCH);
    const translated = await Promise.all(
      batch.map(s => _translateSingle(s, langCode).catch(() => s))
    );
    results.push(...translated);
  }
  return results;
}

module.exports = { translateSchemes };
