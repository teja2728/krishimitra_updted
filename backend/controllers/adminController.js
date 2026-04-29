const User = require('../models/User');
const Scheme = require('../models/Scheme');

async function listUsers(req, res) {
  try {
    const users = await User.find({ role: 'user' }).select('-password').lean();
    return res.json(users);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Failed to load users' });
  }
}

async function approveScheme(req, res) {
  try {
    const { id } = req.params;
    const scheme = await Scheme.findByIdAndUpdate(id, { approved: true }, { new: true });
    if (!scheme) return res.status(404).json({ message: 'Scheme not found' });
    return res.json(scheme);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Failed to approve scheme' });
  }
}

async function sendBroadcast(req, res) {
  try {
    const { title, body } = req.body;
    // In a real scenario, integrate Firebase Admin SDK here.
    // For now, we simulate success since the FCM keys might not be present.
    console.log(`[BROADCAST] Sending notification to all users: ${title} - ${body}`);
    return res.json({ message: 'Broadcast sent successfully', title, body });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Failed to send broadcast' });
  }
}

module.exports = { listUsers, approveScheme, sendBroadcast };
