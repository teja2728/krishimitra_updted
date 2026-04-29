const express = require('express');
const router  = express.Router();
const { chat } = require('../controllers/geminiChatController');
const { requireAuth } = require('../middleware/auth');

// POST /api/gemini/chat  — authenticated users only
router.post('/chat', requireAuth, chat);

module.exports = router;
