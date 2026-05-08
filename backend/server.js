require('dotenv').config();

const express = require('express');
const cors = require('cors');
const connectDB = require('./config/db');

const app = express();

/* ─────────────────────────────────────────────
   BASIC SECURITY CHECKS
───────────────────────────────────────────── */

if (!process.env.JWT_SECRET) {
  console.error('JWT_SECRET missing in .env');
  process.exit(1);
}

if (!process.env.MONGO_URI) {
  console.error('MONGO_URI missing in .env');
  process.exit(1);
}

/* ─────────────────────────────────────────────
   MIDDLEWARE
───────────────────────────────────────────── */

app.use(cors());

app.use(express.json({
  limit: '20mb'
}));

app.use(express.urlencoded({
  extended: true,
  limit: '20mb'
}));

/* ─────────────────────────────────────────────
   STATIC FILES
───────────────────────────────────────────── */

app.use('/uploads', express.static('uploads'));

/* ─────────────────────────────────────────────
   HEALTH CHECK
───────────────────────────────────────────── */

app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'KrishiMitra Backend Running 🚀'
  });
});

app.get('/health', (req, res) => {
  res.json({
    success: true,
    status: 'healthy'
  });
});

/* ─────────────────────────────────────────────
   ROUTES
───────────────────────────────────────────── */

app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/schemes', require('./routes/schemeRoutes'));
app.use('/api/feedback', require('./routes/feedbackRoutes'));
app.use('/api/bookmark', require('./routes/bookmarkRoutes'));
app.use('/api/admin', require('./routes/adminRoutes'));
app.use('/api/gemini', require('./routes/geminiRoutes'));
app.use('/api/personalize', require('./routes/personalizationRoutes'));
app.use('/api/translate', require('./routes/translateRoutes'));
app.use('/api/farm', require('./routes/farmRoutes'));

/* ─────────────────────────────────────────────
   404 HANDLER
───────────────────────────────────────────── */

app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'API Route Not Found'
  });
});

/* ─────────────────────────────────────────────
   GLOBAL ERROR HANDLER
───────────────────────────────────────────── */

app.use((err, req, res, next) => {
  console.error(err);

  res.status(500).json({
    success: false,
    message: 'Internal Server Error'
  });
});

/* ─────────────────────────────────────────────
   START SERVER
───────────────────────────────────────────── */

const PORT = process.env.PORT || 5000;

async function startServer() {
  try {

    await connectDB();

    app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Server running on port ${PORT}`);
    });

  } catch (error) {

    console.error('Server startup failed:', error);

    process.exit(1);
  }
}

startServer();