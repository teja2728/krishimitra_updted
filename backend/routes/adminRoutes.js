const express = require('express');
const { listUsers, approveScheme, sendBroadcast, suspendUser, blockUser, activateUser, deleteUser } = require('../controllers/adminController');
const { requireAuth, requireAdmin } = require('../middleware/auth');

const router = express.Router();

router.use(requireAuth, requireAdmin);

router.get('/users', listUsers);
router.patch('/users/:id/suspend', suspendUser);
router.patch('/users/:id/block', blockUser);
router.patch('/users/:id/activate', activateUser);
router.delete('/users/:id', deleteUser);

router.put('/schemes/:id/approve', approveScheme);
router.post('/broadcast', sendBroadcast);

module.exports = router;
