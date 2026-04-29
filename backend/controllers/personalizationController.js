const Groq = require('groq-sdk');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

/**
 * POST /api/personalize
 * Body: { schemeId, schemeName, description, benefits, eligibility, deadline,
 *         userState, userCrops, userSoilType, userLandSize }
 *
 * Returns: { relevanceScore, whyRelevant, highlight, steps[] }
 *
 * Single Groq call delivers both personalization AND apply steps.
 */
exports.personalizeScheme = async (req, res) => {
  const {
    schemeName, description, benefits = [], eligibility = [], deadline,
    userState, userCrops = [], userSoilType, userLandSize,
  } = req.body;

  if (!schemeName || !userState) {
    return res.status(400).json({ error: 'schemeName and userState are required.' });
  }

  const benefitText    = Array.isArray(benefits)    ? benefits.join('; ')    : benefits;
  const eligibilityText= Array.isArray(eligibility) ? eligibility.join('; ') : eligibility;
  const cropText       = Array.isArray(userCrops)   ? userCrops.join(', ')   : userCrops;

  const prompt = `You are an Indian agriculture scheme advisor. Analyze this scheme for a farmer and return a strict JSON object.

Farmer Profile:
- State: ${userState}
- Crops: ${cropText || 'General farming'}
- Soil Type: ${userSoilType || 'Not specified'}
- Land Size: ${userLandSize || 0} acres

Scheme Details:
- Name: ${schemeName}
- Description: ${description || ''}
- Benefits: ${benefitText}
- Eligibility: ${eligibilityText}
- Deadline: ${deadline || 'Open'}

Return ONLY this JSON object (no markdown, no extra text):
{
  "relevanceScore": <integer 0-100>,
  "whyRelevant": "<one clear sentence why this scheme is relevant to this farmer>",
  "highlight": "<most important benefit for this farmer in 8 words or less>",
  "steps": [
    "<step 1: first action the farmer must take>",
    "<step 2>",
    "<step 3>",
    "<step 4>",
    "<step 5>",
    "<step 6>"
  ]
}`;

  try {
    const completion = await groq.chat.completions.create({
      model: 'llama-3.1-8b-instant',
      messages: [
        {
          role: 'system',
          content: 'You are a JSON-only responder. Output only valid JSON, no markdown, no extra text.',
        },
        { role: 'user', content: prompt },
      ],
      temperature: 0.3,
      max_tokens: 600,
    });

    const raw = completion.choices[0]?.message?.content?.trim() ?? '';
    const jsonStr = raw
      .replace(/^```json\s*/i, '')
      .replace(/^```\s*/i, '')
      .replace(/\s*```$/i, '')
      .trim();

    let parsed;
    try {
      parsed = JSON.parse(jsonStr);
    } catch {
      return res.status(502).json({ error: 'AI returned invalid JSON. Please retry.' });
    }

    return res.json({
      relevanceScore: Math.min(100, Math.max(0, Number(parsed.relevanceScore ?? 50))),
      whyRelevant:    String(parsed.whyRelevant ?? ''),
      highlight:      String(parsed.highlight   ?? ''),
      steps:          Array.isArray(parsed.steps) ? parsed.steps.map(String) : [],
    });

  } catch (err) {
    console.error('[Personalize] Error:', err.message);
    return res.status(500).json({ error: 'Failed to personalize scheme. Please try again.' });
  }
};
