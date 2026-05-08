const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    mobile: { type: String, required: true, unique: true, trim: true },
    password: { type: String, required: true },
    state: { type: String, default: '' },
    language: { type: String, default: '' },
    crops: [{ type: String }],
    soilType: { type: String, default: '' },
    landSize: { type: Number, default: 0 },
    role: {
      type: String,
      enum: ['user', 'admin'],
      default: 'user',
    },
    status: {
      type: String,
      enum: ['ACTIVE', 'SUSPENDED', 'BLOCKED', 'DELETED'],
      default: 'ACTIVE',
    },
    isOnline: { type: Boolean, default: false },
    lastSeen: { type: Date, default: Date.now },
    suspensionReason: { type: String, default: '' },
    deletedAt: { type: Date, default: null },
    deviceType: { type: String, default: '' },
  },
  { timestamps: true }
);

userSchema.set('toJSON', {
  transform: (_, ret) => {
    ret.id = ret._id.toString();
    delete ret._id;
    delete ret.__v;
    delete ret.password;
    return ret;
  },
});

module.exports = mongoose.model('User', userSchema);
