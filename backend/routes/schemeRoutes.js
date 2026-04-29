const express = require('express');
const {
  listAll,
  getSmartSchemes,
  create,
  update,
  remove,
} = require('../controllers/schemeController');
const { requireAuth, requireAdmin } = require('../middleware/auth');

const router = express.Router();

router.get('/', listAll); // For admin or general listing
router.get('/smart', requireAuth, getSmartSchemes); // Smart fetch for users
router.post('/', requireAuth, requireAdmin, create);
router.put('/:id', requireAuth, requireAdmin, update);
router.delete('/:id', requireAuth, requireAdmin, remove);

module.exports = router;
