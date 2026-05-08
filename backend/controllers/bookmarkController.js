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

    // Populate scheme details — use toJSON (not lean) so _id→id transform fires
    const rows = await UserScheme.find({ userId, bookmarked: true })
      .populate('schemeId');

    // Safely extract scheme id (populated object has .toJSON() applied)
    const result = rows.map(r => {
      const scheme = r.schemeId;
      const schemeId = scheme
        ? (scheme.id || scheme._id?.toString() || '')
        : r.schemeId?.toString() || '';
      return { schemeId, bookmarked: r.bookmarked, reminderDate: r.reminderDate };
    });

    return res.json(result);
  } catch (err) {
    console.error('[Bookmark] listByUser error:', err);
    return res.status(500).json({ message: 'Failed to load bookmarks' });
  }
}

/**
 * GET /api/bookmark/:userId/reminders
 * Returns schemeIds that have a pending reminderDate for this user.
 */
async function listRemindersByUser(req, res) {
  try {
    const { userId } = req.params;
    if (!userId) {
      return res.status(400).json({ message: 'userId is required' });
    }

    if (req.user.sub !== userId && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Forbidden' });
    }

    const rows = await UserScheme.find({
      userId,
      reminderDate: { $ne: null },
    }).populate('schemeId');

    const result = rows.map(r => {
      const scheme = r.schemeId;
      const schemeId = scheme
        ? (scheme.id || scheme._id?.toString() || '')
        : r.schemeId?.toString() || '';
      return { schemeId, reminderDate: r.reminderDate };
    });

    return res.json(result);
  } catch (err) {
    console.error('[Reminder] listRemindersByUser error:', err);
    return res.status(500).json({ message: 'Failed to load reminders' });
  }
}

module.exports = { toggle, listByUser, listRemindersByUser };
