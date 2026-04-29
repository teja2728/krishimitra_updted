const mongoose = require('mongoose');

const userSchemeSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    schemeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Scheme', required: true },
    bookmarked: { type: Boolean, default: false },
    reminderDate: { type: Date, default: null },
    viewed: { type: Boolean, default: true },
  },
  { timestamps: true }
);

// Compound index to ensure uniqueness for user+scheme combination
userSchemeSchema.index({ userId: 1, schemeId: 1 }, { unique: true });

userSchemeSchema.set('toJSON', {
  transform: (_, ret) => {
    ret.id = ret._id.toString();
    delete ret._id;
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model('UserScheme', userSchemeSchema);
