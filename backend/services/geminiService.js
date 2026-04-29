const { GoogleGenAI } = require('@google/genai');

const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const fallbackSchemes = [
  {
    name: "PM-Kisan Samman Nidhi",
    state: "All India",
    type: "central",
    category: "subsidy",
    description: "Financial support of ₹6000 per year to small and marginal farmers.",
    benefits: ["₹6000 per year in 3 equal installments"],
    eligibility: ["Small and marginal farmers", "Must hold land"],
    documents: ["Aadhaar Card", "Bank Account Details", "Land Records"],
    deadline: "Open",
    applyLink: "https://pmkisan.gov.in"
  },
  {
    name: "Pradhan Mantri Fasal Bima Yojana",
    state: "All India",
    type: "central",
    category: "insurance",
    description: "Comprehensive crop insurance scheme from pre-sowing to post-harvest losses.",
    benefits: ["Low premium rates", "Full insured amount for crop loss"],
    eligibility: ["All farmers growing notified crops"],
    documents: ["Aadhaar Card", "Land Records", "Bank Passbook"],
    deadline: "Seasonal (Varies by State)",
    applyLink: "https://pmfby.gov.in"
  }
];

let lastGeminiFailureTime = 0;
const FAILURE_COOLDOWN = 60000;

async function generateSchemesForProfile({ state, crops, soilType, landSize }) {
  if (Date.now() - lastGeminiFailureTime < FAILURE_COOLDOWN) {
    console.log("Skipping Gemini due to cooldown");
    throw new Error('COOLDOWN_ACTIVE');
  }

  const maxRetries = 2;
  const retryDelay = 2000;

  const prompt = `
    You are an expert Indian agriculture scheme recommendation AI.
    The user profile is:
    - State: ${state || 'Any'}
    - Crops: ${(crops && crops.length) ? crops.join(', ') : 'Any'}
    - Soil Type: ${soilType || 'Any'}
    - Land Size (Acres): ${landSize || 'Any'}

    Based on this profile, suggest up to 5 real and relevant government agriculture schemes (Central or State level).
    Return ONLY a JSON array, no markdown formatting like \`\`\`json, just the raw array.

    The JSON must perfectly match this structure:
    [
      {
        "name": "Scheme Name",
        "state": "State Name or 'All India'",
        "type": "central" or "state",
        "category": "loan" or "fertilizer" or "machinery" or "subsidy" or "insurance",
        "description": "Short description",
        "benefits": ["Benefit 1", "Benefit 2"],
        "eligibility": ["Eligibility 1", "Eligibility 2"],
        "documents": ["Doc 1", "Doc 2"],
        "deadline": "YYYY-MM-DD or 'Open'",
        "applyLink": "https://direct.official.link"
      }
    ]
  `;

  for (let attempt = 1; attempt <= maxRetries + 1; attempt++) {
    try {
      console.log("Calling Gemini API...");
      const response = await ai.models.generateContent({
        model: 'gemini-2.0-flash',
        contents: prompt,
        config: {
          temperature: 0.2,
        }
      });

      const responseText = response.text.trim();
      const jsonStr = responseText.replace(/^```json\s*/i, '').replace(/\s*```$/i, '');

      let parsed;
      try {
        parsed = JSON.parse(jsonStr);
      } catch (parseError) {
        console.error('Gemini API returned invalid JSON. Attempt:', attempt);
        throw parseError; // Caught by outer try-catch to trigger retry
      }

      if (Array.isArray(parsed) && parsed.length > 0) {
        return parsed;
      } else {
        throw new Error('Gemini returned an empty or invalid array');
      }

    } catch (err) {
      if (attempt <= maxRetries) {
        console.error(`Gemini API failed on attempt ${attempt}. Retrying in ${retryDelay}ms... Error: ${err.message}`);
        await wait(retryDelay);
      } else {
        console.log("Gemini failed, starting cooldown");
        lastGeminiFailureTime = Date.now();
        console.error('Gemini API exhausted all retries. Using fallback.');
        throw err;
      }
    }
  }

  return fallbackSchemes;
}

module.exports = {
  generateSchemesForProfile,
  fallbackSchemes
};
