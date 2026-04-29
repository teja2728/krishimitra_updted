const Groq = require('groq-sdk');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

/**
 * POST /api/gemini/chat
 * Body: { message: string, context?: string }
 * Returns: { reply: string }
 *
 * Model: llama-3.1-8b-instant (Groq free tier)
 */
exports.chat = async (req, res) => {
  const { message, context } = req.body;

  if (!message || typeof message !== 'string' || message.trim().length === 0) {
    return res.status(400).json({ error: 'message field is required.' });
  }

  const systemInstruction =
    `You are KrishiMitra AI, a helpful assistant specialized in Indian agriculture, ` +
    `farming schemes, crop advice, soil health, irrigation, and government subsidies for farmers. ` +
    `Answer clearly and concisely. If asked something outside agriculture, politely redirect to farming topics.` +
    (context ? ` Additional context: ${context}` : '');

  try {
    const completion = await groq.chat.completions.create({
      model: 'llama-3.1-8b-instant',
      messages: [
        { role: 'system', content: systemInstruction },
        { role: 'user',   content: message.trim() },
      ],
      temperature: 0.7,
      max_tokens: 1024,
    });

    const reply = completion.choices[0]?.message?.content?.trim() ?? '';

    if (!reply) {
      return res.status(500).json({ error: 'Empty response from Groq API.' });
    }

    return res.json({ reply });

  } catch (err) {
    console.error('[GroqChat] Error:', err.message);
    return res.status(500).json({ error: 'Failed to get a response. Please try again.' });
  }
};
