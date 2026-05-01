'use strict';

/**
 * FarmRequest.js
 * Stores every crop advisory request for audit, caching, and future
 * features like daily alerts, analytics, and reuse.
 */

const mongoose = require('mongoose');
const { Schema } = mongoose;

// ─── Sub-schemas ──────────────────────────────────────────────────────────────

const LocationSchema = new Schema(
  {
    pincode:        { type: String, trim: true },
    district:       { type: String, trim: true },
    state:          { type: String, trim: true },
    postOfficeName: { type: String, trim: true },
  },
  { _id: false }
);

const WeatherSnapshotSchema = new Schema(
  {
    temperature:  Number,
    feelsLike:    Number,
    humidity:     Number,
    condition:    String,
    windSpeed:    Number,
    rainfall:     Number,
    isFallback:   { type: Boolean, default: false },
    fetchedAt:    String,
    forecast: [
      {
        date:        String,
        temperature: Number,
        humidity:    Number,
        condition:   String,
        rainfall:    Number,
        _id:         false,
      },
    ],
  },
  { _id: false }
);

// ─── Main schema ──────────────────────────────────────────────────────────────

const FarmRequestSchema = new Schema(
  {
    // ── Input ──────────────────────────────────────────────────────────────
    land: {
      type:     Number,
      required: true,
      min:      [0.1, 'Land must be at least 0.1 acres'],
    },
    crop: {
      type:     String,
      required: true,
      trim:     true,
      lowercase: true,
    },
    soil: {
      type:     String,
      required: true,
      trim:     true,
      lowercase: true,
    },
    water: {
      type:     String,
      required: true,
      trim:     true,
      lowercase: true,
    },

    // ── Derived ────────────────────────────────────────────────────────────
    location:       LocationSchema,
    weatherSnapshot: WeatherSnapshotSchema,

    // ── AI output ──────────────────────────────────────────────────────────
    aiResponse: {
      type: String,
      default: '',
    },
    aiModel: {
      type:    String,
      default: 'llama3-70b-8192',
    },

    // ── Meta ───────────────────────────────────────────────────────────────
    userId: {
      type: Schema.Types.ObjectId,
      ref:  'User',
      default: null,
    },
    processingTimeMs: Number,
    error: String,   // populated if request failed
  },
  {
    timestamps: true,   // createdAt, updatedAt
    versionKey: false,
  }
);

// ─── Indexes ──────────────────────────────────────────────────────────────────
// Fast lookup for caching: same pincode+crop combination
FarmRequestSchema.index({ 'location.pincode': 1, crop: 1, createdAt: -1 });
FarmRequestSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('FarmRequest', FarmRequestSchema);
