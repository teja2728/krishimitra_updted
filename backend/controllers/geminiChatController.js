'use strict';
/**
 * geminiChatController.js
 *
 * Two endpoints:
 *
 *   POST /api/gemini/chat
 *     Body (JSON): { message: string, language?: string, context?: string }
 *     Returns:     { reply: string, detectedLanguage: string }
 *
 *   POST /api/gemini/voice
 *     Body (multipart): audio file  +  optional language field
 *     Returns:          { reply: string, inputText: string, detectedLanguage: string }
 *
 * Both endpoints share ONE Groq call path — no logic duplication.
 */

const Groq = require('groq-sdk');
const { speechToText }   = require('../services/cambService');
const { detectLanguage, fromCambLanguage } = require('../services/languageService');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// ─── Constants ────────────────────────────────────────────────────────────────
const CHAT_MODEL    = 'llama-3.1-8b-instant';   // speed + cost for chat
const MAX_TOKENS    = 1024;
const MAX_AUDIO_MB  = parseInt(process.env.MAX_AUDIO_DURATION ?? '30', 10);

// ─── Groq call (with single retry) ───────────────────────────────────────────
async function callGroq(userText, langName, context) {
  const systemPrompt =
    `You are KrishiMitra AI, a helpful assistant specialized in Indian agriculture, ` +
    `farming schemes, crop advice, soil health, irrigation, and government subsidies for farmers. ` +
    `IMPORTANT: Always respond ONLY in ${langName}. ` +
    `Use simple, farmer-friendly language. Avoid complex jargon. ` +
    `If asked something outside agriculture, politely redirect to farming topics in ${langName}.` +
    (context ? ` Additional context: ${context}` : '');

  const attempt = async () =>
    groq.chat.completions.create({
      model: CHAT_MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user',   content: userText.trim() },
      ],
      temperature: 0.7,
      max_tokens:  MAX_TOKENS,
    });

  let completion;
  try {
    completion = await attempt();
  } catch (err) {
    console.warn('[Chat] Groq attempt 1 failed, retrying…', err.message);
    completion = await attempt();  // single retry
  }

  const reply = completion.choices[0]?.message?.content?.trim() ?? '';
  if (!reply) throw new Error('Empty response from Groq.');
  return reply;
}

// ─── POST /api/gemini/chat  (text input) ─────────────────────────────────────
exports.chat = async (req, res) => {
  const { message, language, context } = req.body;

  if (!message || typeof message !== 'string' || message.trim().length === 0) {
    return res.status(400).json({ error: 'message field is required.' });
  }

  try {
    // Language: caller may declare it (from app's languageProvider), else auto-detect
    let langInfo;
    if (language && language.trim()) {
      langInfo = { code2: _toLangCode(language), name: _toDisplayName(language) };
    } else {
      langInfo = await detectLanguage(message);
    }

    const reply = await callGroq(message, langInfo.name, context);

    return res.json({
      reply,
      detectedLanguage: langInfo.name,
    });
  } catch (err) {
    console.error('[Chat] Error:', err.message);
    return res.status(500).json({ error: 'Failed to get a response. Please try again.' });
  }
};

// ─── POST /api/gemini/voice  (voice input via CAMB.AI) ───────────────────────
exports.voice = async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No audio file uploaded. Use multipart/form-data with field "audio".' });
  }

  // File size guard (multer already enforces bytes limit, this is a secondary check)
  const maxBytes = MAX_AUDIO_MB * 1024 * 1024;
  if (req.file.size && req.file.size > maxBytes) {
    return res.status(413).json({ error: `Audio file exceeds ${MAX_AUDIO_MB} MB limit.` });
  }

  try {
    // ── Step 1: Speech → Text via CAMB.AI ───────────────────────────────────
    let transcribedText;
    let detectedLangInfo;

    try {
      const sttResult = await speechToText(
        req.file.buffer,
        req.file.originalname || 'audio.wav',
        req.file.mimetype     || 'audio/wav',
      );
      transcribedText  = sttResult.text;
      detectedLangInfo = await fromCambLanguage(sttResult.language, transcribedText);
    } catch (cambErr) {
      console.error('[Voice] CAMB.AI STT failed:', cambErr.message);
      return res.status(502).json({
        error: `Voice processing unavailable: ${cambErr.message}`,
      });
    }

    // ── Step 2: Language override from client (optional) ─────────────────────
    if (req.body?.language) {
      detectedLangInfo = {
        code2: _toLangCode(req.body.language),
        name:  _toDisplayName(req.body.language),
      };
    }

    // ── Step 3: Groq — respond in detected language ───────────────────────────
    const reply = await callGroq(transcribedText, detectedLangInfo.name, null);

    return res.json({
      reply,
      inputText:        transcribedText,
      detectedLanguage: detectedLangInfo.name,
    });

  } catch (err) {
    console.error('[Voice] Unexpected error:', err.message);
    return res.status(500).json({ error: 'Voice processing failed. Please try again.' });
  }
};

// ─── Helpers ──────────────────────────────────────────────────────────────────
// Map full language name (from app's languageProvider) → 2-letter code
function _toLangCode(lang) {
  switch ((lang || '').toLowerCase()) {
    case 'telugu':   return 'te';
    case 'hindi':    return 'hi';
    case 'kannada':  return 'kn';
    case 'tamil':    return 'ta';
    case 'marathi':  return 'mr';
    default:         return 'en';
  }
}

// Map to display name for Groq prompt
function _toDisplayName(lang) {
  const first = (lang || '').charAt(0).toUpperCase() + (lang || '').slice(1).toLowerCase();
  const valid  = ['Telugu', 'Hindi', 'Kannada', 'Tamil', 'Marathi', 'Bengali', 'Gujarati', 'Punjabi'];
  return valid.includes(first) ? first : 'English';
}
