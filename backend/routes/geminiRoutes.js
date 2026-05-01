const express = require('express');
const router  = express.Router();
const { chat, voice } = require('../controllers/geminiChatController');
const { requireAuth }  = require('../middleware/auth');
const { audioUpload }  = require('../middleware/uploadMiddleware');

// POST /api/gemini/chat  — text message (JSON body)
router.post('/chat', requireAuth, chat);

// POST /api/gemini/voice — audio file (multipart/form-data, field: "audio")
router.post('/voice', requireAuth, audioUpload.single('audio'), voice);

module.exports = router;
