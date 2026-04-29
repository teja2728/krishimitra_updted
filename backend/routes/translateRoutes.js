const express = require('express');
const router  = express.Router();
const { translate } = require('../controllers/translateController');
const { requireAuth } = require('../middleware/auth');

// POST /api/translate  — authenticated users only
router.post('/', requireAuth, translate);

module.exports = router;
