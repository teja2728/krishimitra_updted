const Groq = require('groq-sdk');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

const SUPPORTED_LANGUAGES = ['English', 'Hindi', 'Telugu', 'Kannada'];

/**
 * POST /api/translate
 * Body: { text: string, targetLanguage: string }
 * Returns: { translatedText: string }
 */
exports.translate = async (req, res) => {
  const { text, targetLanguage } = req.body;

  if (!text || typeof text !== 'string' || text.trim().length === 0) {
    return res.status(400).json({ error: 'text field is required.' });
  }

  if (!targetLanguage || !SUPPORTED_LANGUAGES.includes(targetLanguage)) {
    return res.status(400).json({
      error: `targetLanguage must be one of: ${SUPPORTED_LANGUAGES.join(', ')}.`,
    });
  }

  // If already English, return as-is
  if (targetLanguage === 'English') {
    return res.json({ translatedText: text.trim() });
  }

  try {
    const completion = await groq.chat.completions.create({
      model: 'llama-3.1-8b-instant',
      messages: [
        {
          role: 'system',
          content: `You are a professional translator. Translate the following text to ${targetLanguage}. 
Return ONLY the translated text. No explanations, no original text, no quotes, no markdown.`,
        },
        { role: 'user', content: text.trim() },
      ],
      temperature: 0.1,
      max_tokens: 1024,
    });

    const translatedText = completion.choices[0]?.message?.content?.trim() ?? text;
    return res.json({ translatedText });
  } catch (err) {
    console.error('[Translate] Error:', err.message);
    // Graceful fallback — return original text
    return res.json({ translatedText: text });
  }
};
