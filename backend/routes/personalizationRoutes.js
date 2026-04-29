const express = require('express');
const router  = express.Router();
const { personalizeScheme } = require('../controllers/personalizationController');
const { requireAuth } = require('../middleware/auth');

// POST /api/personalize  — authenticated users only
router.post('/', requireAuth, personalizeScheme);

module.exports = router;
