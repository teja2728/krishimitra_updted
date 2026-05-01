'use strict';

/**
 * weatherService.js
 * Fetches current weather + 5-day forecast from OpenWeatherMap.
 *
 * Features:
 *  - Unit conversion to Celsius (metric)
 *  - In-memory cache with 30-minute TTL (Redis-ready drop-in)
 *  - Graceful fallback on API failure
 */

const https = require('https');

const BASE_URL = (process.env.WEATHER_BASE_URL || 'https://api.openweathermap.org/data/2.5').replace(/\/$/, '');
const API_KEY  = process.env.WEATHER_API_KEY || '';
const CACHE_TTL_MS = 30 * 60 * 1000; // 30 minutes

// ─── Simple in-memory cache (replace with Redis client if desired) ─────────────
const _cache = new Map(); // key → { data, expiresAt }

function cacheGet(key) {
  const entry = _cache.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expiresAt) { _cache.delete(key); return null; }
  return entry.data;
}

function cacheSet(key, data) {
  _cache.set(key, { data, expiresAt: Date.now() + CACHE_TTL_MS });
}

// ─── HTTP helper ──────────────────────────────────────────────────────────────

function httpGet(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let raw = '';
      res.on('data', (c) => (raw += c));
      res.on('end', () => {
        try { resolve(JSON.parse(raw)); }
        catch (e) { reject(new Error('Invalid JSON from weather API')); }
      });
    }).on('error', reject);
  });
}

// ─── Parsers ──────────────────────────────────────────────────────────────────

function parseCurrentWeather(data) {
  return {
    temperature:  Math.round(data.main?.temp ?? 0),
    feelsLike:    Math.round(data.main?.feels_like ?? 0),
    humidity:     data.main?.humidity ?? 0,
    condition:    data.weather?.[0]?.description ?? 'N/A',
    conditionCode:data.weather?.[0]?.id ?? 0,
    windSpeed:    data.wind?.speed ?? 0,          // m/s
    rainfall:     data.rain?.['1h'] ?? 0,         // mm/h
    city:         data.name ?? '',
    country:      data.sys?.country ?? '',
    fetchedAt:    new Date().toISOString(),
  };
}

function parseForecast(data) {
  // Group by date and pick midday reading (12:00 or nearest)
  const byDate = {};
  for (const item of (data.list || [])) {
    const date = item.dt_txt?.split(' ')[0];
    if (!date) continue;
    const hour = parseInt(item.dt_txt.split(' ')[1], 10);
    if (!byDate[date] || Math.abs(hour - 12) < Math.abs(byDate[date].hour - 12)) {
      byDate[date] = { hour, item };
    }
  }

  return Object.entries(byDate).slice(0, 5).map(([date, { item }]) => ({
    date,
    temperature: Math.round(item.main?.temp ?? 0),
    humidity:    item.main?.humidity ?? 0,
    condition:   item.weather?.[0]?.description ?? 'N/A',
    rainfall:    item.rain?.['3h'] ?? 0,
    windSpeed:   item.wind?.speed ?? 0,
  }));
}

// ─── Fallback snapshot ────────────────────────────────────────────────────────

function buildFallback(district) {
  console.warn(`[WeatherService] Using fallback weather data for "${district}"`);
  return {
    current: {
      temperature: 28, feelsLike: 30, humidity: 65,
      condition: 'data unavailable', conditionCode: 0,
      windSpeed: 3, rainfall: 0,
      city: district, country: 'IN',
      fetchedAt: new Date().toISOString(),
      isFallback: true,
    },
    forecast: [],
  };
}

// ─── Main export ──────────────────────────────────────────────────────────────

/**
 * @param {string} district  District/city name from pincode lookup
 * @returns {{ current: object, forecast: object[] }}
 */
async function getWeather(district) {
  if (!API_KEY) {
    console.warn('[WeatherService] WEATHER_API_KEY not set — using fallback.');
    return buildFallback(district);
  }

  const cacheKey = `weather:${district.toLowerCase()}`;
  const cached = cacheGet(cacheKey);
  if (cached) {
    console.log(`[WeatherService] Cache hit for "${district}"`);
    return cached;
  }

  try {
    const encDistrict = encodeURIComponent(district);

    const [currentData, forecastData] = await Promise.all([
      httpGet(`${BASE_URL}/weather?q=${encDistrict},IN&units=metric&appid=${API_KEY}`),
      httpGet(`${BASE_URL}/forecast?q=${encDistrict},IN&units=metric&appid=${API_KEY}`),
    ]);

    if (currentData.cod !== 200 && currentData.cod !== '200') {
      throw new Error(currentData.message || 'Weather API returned an error');
    }

    const result = {
      current:  parseCurrentWeather(currentData),
      forecast: parseForecast(forecastData),
    };

    cacheSet(cacheKey, result);
    console.log(`[WeatherService] Fetched & cached weather for "${district}"`);
    return result;

  } catch (err) {
    console.error(`[WeatherService] API error: ${err.message}`);
    return buildFallback(district);
  }
}

module.exports = { getWeather };
