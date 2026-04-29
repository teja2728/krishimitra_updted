const express = require('express');
const { listUsers, approveScheme, sendBroadcast } = require('../controllers/adminController');
const { requireAuth, requireAdmin } = require('../middleware/auth');

const router = express.Router();

router.use(requireAuth, requireAdmin);

router.get('/users', listUsers);
router.put('/schemes/:id/approve', approveScheme);
router.post('/broadcast', sendBroadcast);

module.exports = router;
