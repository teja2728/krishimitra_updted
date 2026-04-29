const express = require('express');
const { register, login, adminLogin, updateProfile } = require('../controllers/authController');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.post('/register', register);
router.post('/login', login);
router.post('/admin-login', adminLogin);
router.put('/profile', requireAuth, updateProfile);

module.exports = router;
