const Scheme = require('../models/Scheme');
const User   = require('../models/User');
const { getSmartSchemes }    = require('../services/groqSchemeService');
const { translateSchemes }   = require('../services/translationService');

// ─── Response mapper ──────────────────────────────────────────────────────────
function schemeResponse(s) {
  return {
    id:            s._id ? s._id.toString() : s.id,
    name:          s.name,
    state:         s.state,
    type:          s.type,
    category:      s.category,
    description:   s.description,
    benefits:      s.benefits  || [],
    eligibility:   s.eligibility || [],
    documents:     s.documents || [],
    deadline:      s.deadline,
    applyLink:     s.applyLink,
    source:        s.source        || 'official',
    confidence:    s.confidence    ?? 1.0,
    fetchedAt:     s.fetchedAt,
    lastVerifiedAt:s.lastVerifiedAt,
    isAiGenerated: s.isAiGenerated,
    approved:      s.approved,
  };
}

// ─── GET /api/schemes/smart ───────────────────────────────────────────────────
/**
 * DB-first fetch:
 *   1. If fresh DB data exists  → return immediately
 *   2. Else → Groq → validate → store → return
 * Supports ?lang=te|hi|kn for on-the-fly backend translation via Groq.
 */
async function getSmartSchemesHandler(req, res) {
  try {
    const lang = (req.query.lang || 'en').toLowerCase().trim();

    const user = await User.findById(req.user.sub).lean();
    if (!user) return res.status(404).json({ message: 'User not found' });

    const profile = {
      state:    user.state    || '',
      crops:    user.crops    || [],
      soilType: user.soilType || '',
      landSize: user.landSize || 0,
    };

    const { schemes, source } = await getSmartSchemes(profile);
    console.log(`[Schemes] ${schemes.length} schemes (source: ${source}, lang: ${lang})`);

    // Map to API shape first (plain objects with string id)
    const mapped = schemes.map(schemeResponse);

    // Translate if not English
    const finalSchemes = lang !== 'en'
      ? await translateSchemes(mapped, lang)
      : mapped;

    return res.json(finalSchemes);

  } catch (err) {
    console.error('[Schemes] Smart fetch error:', err.message);
    return res.status(500).json({ message: err.message || 'Failed to fetch schemes.' });
  }
}

// ─── GET /api/schemes  (admin: list all) ─────────────────────────────────────
async function listAll(req, res) {
  try {
    const lang = (req.query.lang || 'en').toLowerCase().trim();
    const schemes = await Scheme.find().sort({ createdAt: -1 }).lean();
    const mapped  = schemes.map(schemeResponse);

    const finalSchemes = lang !== 'en'
      ? await translateSchemes(mapped, lang)
      : mapped;

    return res.json(finalSchemes);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Failed to load schemes' });
  }
}

// ─── POST /api/schemes  (admin: create) ──────────────────────────────────────
async function create(req, res) {
  try {
    const {
      name, state, type, category, description,
      benefits, eligibility, documents, deadline, applyLink,
    } = req.body;

    if (!name || !type) {
      return res.status(400).json({ message: 'name and type are required' });
    }

    const typeNorm = String(type).toLowerCase() === 'central' ? 'central' : 'state';
    const stateNorm = typeNorm === 'central' ? 'All' : (state ?? '');

    const scheme = await Scheme.create({
      name:        String(name).trim(),
      state:       stateNorm,
      type:        typeNorm,
      category:    category    ?? '',
      description: description ?? '',
      benefits:    Array.isArray(benefits)    ? benefits    : [],
      eligibility: Array.isArray(eligibility) ? eligibility : [],
      documents:   Array.isArray(documents)   ? documents   : [],
      deadline:    deadline    ?? '',
      applyLink:   applyLink   ?? '',
      source:      'official',
      confidence:  1.0,
      isAiGenerated: false,
      approved:    true,
      fetchedAt:      new Date(),
      lastVerifiedAt: new Date(),
    });

    return res.status(201).json(schemeResponse(scheme));
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Failed to create scheme' });
  }
}

// ─── PUT /api/schemes/:id  (admin: update) ───────────────────────────────────
async function update(req, res) {
  try {
    const scheme = await Scheme.findByIdAndUpdate(
      req.params.id,
      { ...req.body, lastVerifiedAt: new Date() },
      { new: true }
    );
    if (!scheme) return res.status(404).json({ message: 'Scheme not found' });
    return res.json(schemeResponse(scheme));
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Failed to update scheme' });
  }
}

// ─── DELETE /api/schemes/:id  (admin: remove) ────────────────────────────────
async function remove(req, res) {
  try {
    const scheme = await Scheme.findByIdAndDelete(req.params.id);
    if (!scheme) return res.status(404).json({ message: 'Scheme not found' });
    return res.json({ message: 'Scheme deleted' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Failed to delete scheme' });
  }
}

module.exports = { listAll, getSmartSchemes: getSmartSchemesHandler, create, update, remove };
