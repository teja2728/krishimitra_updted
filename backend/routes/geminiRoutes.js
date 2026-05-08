const express = require('express');
const router  = express.Router();
const { chat } = require('../controllers/geminiChatController');
const { requireAuth }  = require('../middleware/auth');

// POST /api/gemini/chat  — text message (JSON body)
router.post('/chat', requireAuth, chat);

module.exports = router;
