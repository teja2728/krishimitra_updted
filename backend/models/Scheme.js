const mongoose = require('mongoose');

const schemeSchema = new mongoose.Schema(
  {
    name:        { type: String, required: true, trim: true },
    state:       { type: String, default: 'All', trim: true },
    type:        { type: String, enum: ['central', 'state'], required: true, default: 'state' },
    category:    { type: String, default: '' },
    description: { type: String, default: '' },
    benefits:    [{ type: String }],
    eligibility: [{ type: String }],
    documents:   [{ type: String }],
    applyLink:   { type: String, default: '' },
    deadline:    { type: String, default: '' },

    // ── Metadata ──────────────────────────────────────────────────────────────
    source:          { type: String, enum: ['ai', 'official'], default: 'official' },
    confidence:      { type: Number, default: 1.0, min: 0, max: 1 },
    fetchedAt:       { type: Date, default: Date.now },
    lastVerifiedAt:  { type: Date, default: Date.now },

    isAiGenerated:   { type: Boolean, default: false },
    approved:        { type: Boolean, default: true },
  },
  { timestamps: true }
);

// Index for fast state-based lookups
schemeSchema.index({ state: 1, type: 1 });
schemeSchema.index({ name: 1 }, { unique: true });

schemeSchema.set('toJSON', {
  transform: (_, ret) => {
    ret.id = ret._id.toString();
    delete ret._id;
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model('Scheme', schemeSchema);
