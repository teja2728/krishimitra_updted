'use strict';
/**
 * geminiChatController.js
 *
 * Endpoint:
 *
 *   POST /api/gemini/chat
 *     Body (JSON): { message: string, language?: string, context?: string }
 *     Returns:     { reply: string, detectedLanguage: string }
 *
 * Domain restriction: Only agriculture-related queries are forwarded to Groq.
 * Off-topic queries are rejected with a friendly message — no LLM call is made.
 */

const Groq = require('groq-sdk');
const { detectLanguage } = require('../services/languageService');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// ─── Constants ────────────────────────────────────────────────────────────────
const CHAT_MODEL  = 'llama-3.1-8b-instant';   // speed + cost for chat
const MAX_TOKENS  = 1024;

// ─── Agriculture keyword bank (EN + TE + HI + KN) ────────────────────────────
const AGRI_KEYWORDS = [
  // English
  'farm','farmer','farming','agriculture','agri','crop','crops','cultivation',
  'cultivate','harvest','harvesting','field','plantation','soil','land','acre',
  'hectare','compost','manure','fertilizer','fertiliser','urea','npk','organic',
  'mulch','tilling','ploughing','irrigation','drip','sprinkler','canal',
  'rainwater','borewell','drainage','seed','seeds','seedling','paddy','rice',
  'wheat','maize','corn','sugarcane','cotton','soybean','groundnut','peanut',
  'pulses','lentils','chickpea','mustard','sunflower','barley','millet',
  'jowar','bajra','ragi','turmeric','ginger','chilli','pepper','tomato',
  'onion','potato','vegetables','fruits','mango','banana','papaya','coconut',
  'rubber','jute','hemp','tea','coffee','spice','pest','pesticide','insecticide',
  'herbicide','fungicide','weed','disease','blight','aphid','locust','spray',
  'livestock','cattle','cow','buffalo','goat','sheep','pig','poultry','chicken',
  'dairy','milk','egg','breed','veterinary','vet','animal husbandry','fish',
  'fishery','aquaculture','beekeeping','honey','tractor','thresher','harvester',
  'storage','silo','warehouse','scheme','yojana','subsidy','loan','credit',
  'kcc','kisan','pm-kisan','pm kisan','pmfby','fasal bima','mgnrega','msp',
  'minimum support price','e-nam','apmc','mandi','market','price','procurement',
  'weather','monsoon','rain','drought','flood','climate','temperature','humidity',
  'forecast','season','rabi','kharif','zaid','crop rotation','intercropping',
  'greenhouse','polyhouse','hydroponic','vertical farming','precision agriculture',
  'natural farming','sustainable','zero budget','yield','produce','fpo',
  'cooperative','agro','kृषि','खेती',
  // Telugu
  'రైతు','వ్యవసాయం','పంట','విత్తనాలు','నేల','ఎరువు','నీటిపారుదల',
  'పురుగుమందు','కంది','వరి','గోధుమ','మొక్కజొన్న','వేరుశనగ','మిర్చి',
  'టమాటో','ఉల్లిపాయ','అరటి','పశుపాలన','పాడి','యోజన','సబ్సిడీ','రుణం',
  'వర్షం','కరువు','వాతావరణం','ధర','మండి','కిసాన్','ఫసల్ బీమా',
  // Hindi
  'किसान','खेती','फसल','बीज','मिट्टी','खाद','सिंचाई','कीटनाशक','गेहूं',
  'चावल','मक्का','दलहन','सरसों','कपास','गन्ना','आलू','टमाटर','प्याज',
  'पशुपालन','गाय','भैंस','मुर्गीपालन','डेयरी','योजना','सब्सिडी','ऋण',
  'बारिश','सूखा','मौसम','मंडी','भाव','पीएम किसान','फसल बीमा','जैविक',
  'उर्वरक','रबी','खरीफ','कृषि',
  // Kannada
  'ರೈತ','ಕೃಷಿ','ಬೆಳೆ','ಬೀಜ','ಮಣ್ಣು','ಗೊಬ್ಬರ','ನೀರಾವರಿ','ಕೀಟನಾಶಕ',
  'ಭತ್ತ','ಗೋಧಿ','ಜೋಳ','ರಾಗಿ','ತೊಗರಿ','ಕಡಲೆ','ಮೆಣಸಿನಕಾಯಿ','ಟೊಮ್ಯಾಟೊ',
  'ಈರುಳ್ಳಿ','ಪಶುಪಾಲನೆ','ಹಾಲು','ಯೋಜನೆ','ಸಹಾಯಧನ','ಸಾಲ','ಮಳೆ','ಬರ',
  'ಹವಾಮಾನ','ಮಂಡಿ','ಕಿಸಾನ್','ಸಾವಯವ',
];

// Obvious off-topic signals — if any of these appear AND no agri keyword found → block
const OFF_TOPIC_SIGNALS = [
  'java','python','javascript','typescript','kotlin','swift','rust','golang',
  'c++','c#','ruby','php','react','angular','vue','nodejs','node.js','express',
  'programming','coding','code','algorithm','data structure','fibonacci',
  'factorial','sorting','linked list','binary tree','blockchain','nft',
  'cryptocurrency','bitcoin','ethereum','movie','film','netflix','cricket',
  'ipl','football','gaming','game','pubg','fortnite','valorant','playstation',
  'xbox','politics','election','bollywood','celebrity','hack','hacking',
  'malware','relationship','girlfriend','boyfriend','love story','homework',
  'html','css','sql',
];

// Greeting/meta patterns — allow these to pass through
const GREETING_PATTERNS = [
  'hello','hi ','namaste','help','who are you','what can you do','your name',
  'about you','krishimitra',
];

/**
 * Returns true if the message appears agriculture-related.
 * @param {string} message
 */
function isAgricultureQuery(message) {
  const norm = message.toLowerCase().trim();

  // 1. Check agri keywords
  const hasAgri = AGRI_KEYWORDS.some(kw => norm.includes(kw));
  if (hasAgri) return true;

  // 2. Check off-topic signals
  const hasOffTopic = OFF_TOPIC_SIGNALS.some(sig => norm.includes(sig));
  if (hasOffTopic) return false;

  // 3. Greetings / meta — pass through
  const isGreeting = GREETING_PATTERNS.some(g => norm.startsWith(g) || norm.includes(g));
  if (isGreeting) return true;

  // 4. Short ambiguous query — let AI handle it
  if (norm.split(' ').length <= 4) return true;

  // 5. Default block for longer unrecognised queries
  return false;
}

/**
 * Return friendly block message in the correct language.
 * @param {string} langName
 */
function getBlockMessage(langName) {
  switch ((langName || '').toLowerCase()) {
    case 'telugu':
      return '🌾 నేను KrishiMitra AI అసిస్టెంట్‌ని. నేను వ్యవసాయం, పంటలు, రైతు పథకాలు మరియు వ్యవసాయ విషయాల గురించి మాత్రమే సహాయం చేయగలను.\n\nమీరు ఇవి అడగవచ్చు:\n• పంటలు & విత్తనాలు\n• ఎరువులు & నీటిపారుదల\n• ప్రభుత్వ పథకాలు\n• వ్యాధి నివారణ\n• వాతావరణం & మండి ధరలు';
    case 'hindi':
      return '🌾 मैं KrishiMitra AI असिस्टेंट हूँ। मैं केवल कृषि, फसल, किसान योजनाओं और खेती से जुड़े विषयों पर सहायता कर सकता हूँ।\n\nआप पूछ सकते हैं:\n• फसलें और बीज\n• उर्वरक और सिंचाई\n• सरकारी योजनाएं\n• रोग नियंत्रण\n• मौसम और मंडी भाव';
    case 'kannada':
      return '🌾 ನಾನು KrishiMitra AI ಸಹಾಯಕ. ನಾನು ಕೃಷಿ, ಬೆಳೆ, ರೈತ ಯೋಜನೆಗಳು ಮತ್ತು ಕೃಷಿ ವಿಷಯಗಳ ಬಗ್ಗೆ ಮಾತ್ರ ಸಹಾಯ ಮಾಡಬಲ್ಲೆ.\n\nನೀವು ಕೇಳಬಹುದು:\n• ಬೆಳೆ ಮತ್ತು ಬೀಜ\n• ಗೊಬ್ಬರ ಮತ್ತು ನೀರಾವರಿ\n• ಸರ್ಕಾರಿ ಯೋಜನೆಗಳು\n• ರೋಗ ನಿಯಂತ್ರಣ\n• ಹವಾಮಾನ ಮತ್ತು ಮಂಡಿ ಬೆಲೆ';
    default:
      return '🌾 I am KrishiMitra AI, your agriculture assistant.\nI only answer questions about farming, crops, and farmer welfare.\n\nYou can ask me about:\n• Crops & Seeds\n• Fertilizers & Irrigation\n• Government Schemes\n• Pest & Disease Control\n• Weather & Market Prices\n• Soil Health & Organic Farming';
  }
}

// ─── Groq call (with single retry) ───────────────────────────────────────────
async function callGroq(userText, langName, context) {
  const systemPrompt =
    `You are KrishiMitra AI, an expert assistant exclusively for Indian farmers. ` +
    `STRICT RULES:\n` +
    `1. You ONLY answer questions about agriculture, farming, crops, soil, ` +
    `   irrigation, fertilizers, pesticides, livestock, government schemes for ` +
    `   farmers, weather for farming, market prices (mandi), and related topics.\n` +
    `2. If asked about coding, programming, entertainment, sports, politics, ` +
    `   mathematics, or any non-agriculture topic, politely decline and suggest ` +
    `   the user ask a farming-related question.\n` +
    `3. ALWAYS respond ONLY in ${langName}.\n` +
    `4. Use simple, farmer-friendly language. Avoid technical jargon.\n` +
    `5. Be helpful, accurate, and encouraging to farmers.` +
    (context ? `\nAdditional context: ${context}` : '');

  const attempt = async () =>
    groq.chat.completions.create({
      model: CHAT_MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user',   content: userText.trim() },
      ],
      temperature: 0.7,
      max_tokens:  MAX_TOKENS,
    });

  let completion;
  try {
    completion = await attempt();
  } catch (err) {
    console.warn('[Chat] Groq attempt 1 failed, retrying…', err.message);
    completion = await attempt();  // single retry
  }

  const reply = completion.choices[0]?.message?.content?.trim() ?? '';
  if (!reply) throw new Error('Empty response from Groq.');
  return reply;
}

// ─── POST /api/gemini/chat ────────────────────────────────────────────────────
exports.chat = async (req, res) => {
  const { message, language, context } = req.body;

  if (!message || typeof message !== 'string' || message.trim().length === 0) {
    return res.status(400).json({ error: 'message field is required.' });
  }

  // Resolve language
  let langName = 'English';
  if (language && language.trim()) {
    langName = _toDisplayName(language);
  } else {
    try {
      const langInfo = await detectLanguage(message);
      langName = langInfo.name || 'English';
    } catch (_) {
      langName = 'English';
    }
  }

  // ── Backend domain restriction (second layer after Flutter client check) ──
  if (!isAgricultureQuery(message)) {
    console.log(`[Chat] Blocked non-agri query: "${message.substring(0, 80)}"`);
    return res.json({
      reply: getBlockMessage(langName),
      detectedLanguage: langName,
      blocked: true,
    });
  }

  console.log(`[Chat] Allowed agri query: "${message.substring(0, 80)}"`);

  try {
    const reply = await callGroq(message, langName, context);
    return res.json({ reply, detectedLanguage: langName });
  } catch (err) {
    console.error('[Chat] Error:', err.message);
    return res.status(500).json({ error: 'Failed to get a response. Please try again.' });
  }
};

// ─── Helpers ──────────────────────────────────────────────────────────────────
function _toDisplayName(lang) {
  const first = (lang || '').charAt(0).toUpperCase() + (lang || '').slice(1).toLowerCase();
  const valid  = ['Telugu', 'Hindi', 'Kannada', 'Tamil', 'Marathi', 'Bengali', 'Gujarati', 'Punjabi'];
  return valid.includes(first) ? first : 'English';
}
