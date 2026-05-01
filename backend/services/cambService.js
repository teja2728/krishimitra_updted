'use strict';
/**
 * cambService.js
 * Wraps the CAMB.AI REST API for Speech-to-Text.
 *
 * ⚠️  CAMB.AI is OPTIONAL — if CAMB_API_KEY is not set the service throws
 *     a clear error so the chatController can fall back to text-only mode.
 *
 * Docs: https://docs.camb.ai
 */

const https = require('https');
const http  = require('http');

// ─── Config ───────────────────────────────────────────────────────────────────
function getCambKey() {
  const key = process.env.CAMB_API_KEY;
  if (!key || key.trim() === '' || key === 'your_camb_api_key_here') {
    throw new Error(
      'CAMB_API_KEY is not configured. Voice input requires a CAMB.AI API key. ' +
      'Add CAMB_API_KEY=<your_key> to .env or use text input instead.'
    );
  }
  return key.trim();
}

const CAMB_BASE = (process.env.CAMB_BASE_URL || 'https://api.camb.ai').replace(/\/$/, '');

// ─── Low-level fetch helper (no external deps) ────────────────────────────────
function fetchJson(url, options = {}, bodyBuffer = null) {
  return new Promise((resolve, reject) => {
    const parsed   = new URL(url);
    const useHttps = parsed.protocol === 'https:';
    const lib      = useHttps ? https : http;

    const reqOpts = {
      hostname: parsed.hostname,
      port:     parsed.port || (useHttps ? 443 : 80),
      path:     parsed.pathname + (parsed.search || ''),
      method:   options.method  || 'GET',
      headers:  options.headers || {},
    };

    const req = lib.request(reqOpts, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const raw = Buffer.concat(chunks).toString('utf-8');
        try {
          resolve({ status: res.statusCode, body: JSON.parse(raw) });
        } catch {
          resolve({ status: res.statusCode, body: raw });
        }
      });
    });

    req.on('error', reject);
    if (bodyBuffer) req.write(bodyBuffer);
    req.end();
  });
}

// ─── Multipart builder ────────────────────────────────────────────────────────
function buildMultipart(audioBuffer, filename, mimeType) {
  const boundary = `----KrishiMitraBoundary${Date.now()}`;
  const CRLF     = '\r\n';

  const header = [
    `--${boundary}`,
    `Content-Disposition: form-data; name="audio"; filename="${filename}"`,
    `Content-Type: ${mimeType}`,
    '',
    '',
  ].join(CRLF);

  const footer = `${CRLF}--${boundary}--${CRLF}`;

  const body = Buffer.concat([
    Buffer.from(header, 'utf-8'),
    audioBuffer,
    Buffer.from(footer, 'utf-8'),
  ]);

  return { boundary, body };
}

// ─── Speech-to-Text ───────────────────────────────────────────────────────────
/**
 * Transcribes audio via CAMB.AI STT endpoint.
 * @param {Buffer} audioBuffer  Raw audio bytes
 * @param {string} filename     e.g. 'input.wav'
 * @param {string} mimeType     e.g. 'audio/wav'
 * @returns {{ text: string, language?: string }}
 */
async function speechToText(audioBuffer, filename = 'audio.wav', mimeType = 'audio/wav') {
  const key = getCambKey();

  const { boundary, body } = buildMultipart(audioBuffer, filename, mimeType);

  const result = await fetchJson(
    `${CAMB_BASE}/apis/stt`,
    {
      method: 'POST',
      headers: {
        'x-api-key':     key,
        'Content-Type':  `multipart/form-data; boundary=${boundary}`,
        'Content-Length': body.length,
      },
    },
    body,
  );

  if (result.status !== 200) {
    throw new Error(`CAMB STT failed (HTTP ${result.status}): ${JSON.stringify(result.body)}`);
  }

  // CAMB.AI returns { text: string, language?: string }
  const text     = result.body?.text     || result.body?.transcription || '';
  const language = result.body?.language || result.body?.detected_language || null;

  if (!text.trim()) throw new Error('CAMB STT returned empty transcription.');

  return { text: text.trim(), language };
}

module.exports = { speechToText };
