'use strict';
/**
 * uploadMiddleware.js
 * Multer configuration for audio file uploads.
 * Accepts: .wav, .mp3, .m4a, .ogg, .webm, .aac
 * Limit:   10 MB per file (raw audio from a 30s recording is typically < 5 MB)
 */

const multer = require('multer');
const path   = require('path');

const ALLOWED_EXTENSIONS = ['.wav', '.mp3', '.m4a', '.ogg', '.webm', '.aac'];
const ALLOWED_MIMETYPES  = [
  'audio/wav', 'audio/x-wav', 'audio/wave',
  'audio/mpeg', 'audio/mp3',
  'audio/mp4', 'audio/m4a', 'audio/x-m4a',
  'audio/ogg', 'audio/webm',
  'audio/aac',
];

const storage = multer.memoryStorage();  // keep in RAM buffer — no temp files

function fileFilter(_req, file, cb) {
  const ext  = path.extname(file.originalname).toLowerCase();
  const mime = file.mimetype.toLowerCase();

  if (ALLOWED_EXTENSIONS.includes(ext) || ALLOWED_MIMETYPES.includes(mime)) {
    cb(null, true);
  } else {
    cb(new Error(`Unsupported audio format "${ext}". Use WAV, MP3, M4A, OGG, WEBM or AAC.`), false);
  }
}

const audioUpload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize:  10 * 1024 * 1024,  // 10 MB
    files:     1,
  },
});

module.exports = { audioUpload };
