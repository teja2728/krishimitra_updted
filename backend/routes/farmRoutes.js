'use strict';

/**
 * farmRoutes.js
 * Routes for the AI Crop Advisor feature.
 *
 * Public:
 *   POST /api/farm/analyze        → analyze farm & get AI advisory
 *
 * Public (read-only):
 *   GET  /api/farm/history/:pincode → last 10 advisories for a pincode
 */

const express = require('express');
const router  = express.Router();
const { analyzeFarm, getHistory, downloadPDF } = require('../controllers/farmController');

// POST /api/farm/analyze
router.post('/analyze', analyzeFarm);

// GET  /api/farm/history/:pincode
router.get('/history/:pincode', getHistory);

// POST /api/farm/download-pdf  — streams PDF report
router.post('/download-pdf', downloadPDF);

module.exports = router;
