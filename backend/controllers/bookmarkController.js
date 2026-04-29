const UserScheme = require('../models/UserScheme');

async function toggle(req, res) {
  try {
    const { schemeId, reminderDate } = req.body;
    if (!schemeId) {
      return res.status(400).json({ message: 'schemeId is required' });
    }
    const userId = req.user.sub;

    let userScheme = await UserScheme.findOne({ userId, schemeId });
    
    if (userScheme) {
      // Toggle if no reminder is explicitly passed, otherwise update
      if (reminderDate !== undefined) {
        userScheme.reminderDate = reminderDate;
        if (reminderDate) userScheme.bookmarked = true; // Auto-bookmark if reminding
      } else {
        userScheme.bookmarked = !userScheme.bookmarked;
      }
      await userScheme.save();
    } else {
      userScheme = await UserScheme.create({
        userId,
        schemeId,
        bookmarked: true,
        reminderDate: reminderDate || null
      });
    }

    return res.json({ 
      schemeId, 
      bookmarked: userScheme.bookmarked,
      reminderDate: userScheme.reminderDate
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Bookmark update failed' });
  }
}

async function listByUser(req, res) {
  try {
    const { userId } = req.params;
    if (!userId) {
      return res.status(400).json({ message: 'userId is required' });
    }

    if (req.user.sub !== userId && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Forbidden' });
    }

    // Populate scheme details
    const rows = await UserScheme.find({ userId, bookmarked: true }).populate('schemeId').lean();
    return res.json(rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Failed to load bookmarks' });
  }
}

module.exports = { toggle, listByUser };
