const express = require('express');
const { toggle, listByUser, listRemindersByUser } = require('../controllers/bookmarkController');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.post('/', requireAuth, toggle);
router.get('/:userId', requireAuth, listByUser);
router.get('/:userId/reminders', requireAuth, listRemindersByUser);

module.exports = router;
