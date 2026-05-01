require('dotenv').config();

if (!process.env.JWT_SECRET) {
  console.error('JWT_SECRET is required in .env');
  process.exit(1);
}

const express = require('express');
const cors = require('cors');
const connectDB = require('./config/db');

const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (_, res) => res.json({ ok: true }));

app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/schemes', require('./routes/schemeRoutes'));
app.use('/api/feedback', require('./routes/feedbackRoutes'));
app.use('/api/bookmark', require('./routes/bookmarkRoutes'));
app.use('/api/admin', require('./routes/adminRoutes'));
app.use('/api/gemini', require('./routes/geminiRoutes'));
app.use('/api/personalize', require('./routes/personalizationRoutes'));
app.use('/api/translate', require('./routes/translateRoutes'));
app.use('/api/farm',      require('./routes/farmRoutes'));

// ─── Graceful port binding ───────────────────────────────────────────────────
const BASE_PORT = Number(process.env.PORT) || 5000;

function startServer(port, attempt = 0) {
  if (attempt > 10) {
    console.error('Could not find a free port after 10 attempts. Exiting.');
    process.exit(1);
  }

  const server = app.listen(port, '0.0.0.0')
    .on('listening', () => {
      console.log(`KrishiMitra API listening on port ${port}`);
    })
    .on('error', (err) => {
      if (err.code === 'EADDRINUSE') {
        console.warn(`Port ${port} in use — trying ${port + 1}…`);
        startServer(port + 1, attempt + 1);
      } else {
        console.error('Server error:', err);
        process.exit(1);
      }
    });

  // ─── Clean shutdown (prevents EADDRINUSE on --watch restart) ──────────────
  const shutdown = (signal) => {
    console.log(`\n${signal} received — closing server…`);
    server.close(() => {
      console.log('Server closed. Exiting.');
      process.exit(0);
    });
    // Force-exit if close takes too long
    setTimeout(() => process.exit(1), 5000).unref();
  };

  process.once('SIGTERM', () => shutdown('SIGTERM'));
  process.once('SIGINT',  () => shutdown('SIGINT'));
}

// ─── Connect DB then start ───────────────────────────────────────────────────
connectDB()
  .then(() => startServer(BASE_PORT))
  .catch((err) => {
    console.error('Failed to connect to DB:', err);
    process.exit(1);
  });
