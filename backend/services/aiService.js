'use strict';

/**
 * aiService.js
 * Calls the Groq LLM (llama3-70b-8192) with the crop advisory prompt.
 *
 * Features:
 *  - AbortController-based timeout (25 s)
 *  - One automatic retry on transient failure
 *  - Response content validation
 */

const Groq = require('groq-sdk');

const MODEL          = 'llama-3.3-70b-versatile'; // quality model for crop advisory
const TIMEOUT_MS     = 25_000;
const MAX_TOKENS     = 2048;
const TEMPERATURE    = 0.4;

// Lazy-initialise so server can start even if key is absent (will throw at call time)
let _groqClient = null;
function getClient() {
  if (!process.env.GROQ_API_KEY) throw new Error('GROQ_API_KEY is not set in environment.');
  if (!_groqClient) _groqClient = new Groq({ apiKey: process.env.GROQ_API_KEY });
  return _groqClient;
}

// ─── Core call ────────────────────────────────────────────────────────────────

async function callGroq(prompt) {
  const client = getClient();

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const completion = await client.chat.completions.create(
      {
        model: MODEL,
        messages: [
          {
            role: 'system',
            content:
              'You are KrishiMitra, an expert Indian agricultural advisor. ' +
              'Respond with structured, practical farming advice in clear English.',
          },
          { role: 'user', content: prompt },
        ],
        temperature: TEMPERATURE,
        max_tokens:  MAX_TOKENS,
      },
      { signal: controller.signal }
    );

    const text = completion.choices?.[0]?.message?.content?.trim();
    if (!text) throw new Error('Groq returned an empty response.');
    return text;

  } finally {
    clearTimeout(timer);
  }
}

// ─── Public API with retry ────────────────────────────────────────────────────

/**
 * @param {string} prompt  Full prompt string from promptBuilder
 * @returns {string}       Advisory text from the model
 */
async function getCropAdvisory(prompt) {
  // Attempt 1
  try {
    console.log('[AIService] Calling Groq (attempt 1)…');
    const result = await callGroq(prompt);
    console.log('[AIService] Groq responded successfully.');
    return result;
  } catch (err) {
    console.warn(`[AIService] Attempt 1 failed: ${err.message}. Retrying once…`);
  }

  // Attempt 2 (single retry)
  try {
    console.log('[AIService] Calling Groq (attempt 2)…');
    const result = await callGroq(prompt);
    console.log('[AIService] Groq retry succeeded.');
    return result;
  } catch (err) {
    console.error(`[AIService] Both attempts failed: ${err.message}`);
    throw new Error(`AI advisory service unavailable: ${err.message}`);
  }
}

module.exports = { getCropAdvisory };
