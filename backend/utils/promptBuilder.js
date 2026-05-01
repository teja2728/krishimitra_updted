'use strict';

/**
 * promptBuilder.js
 * Assembles the structured agricultural advisory prompt sent to the Groq LLM.
 * Designed to be extended (Telugu, voice, disease prediction, etc.).
 */

/**
 * Format 5-day forecast into readable bullet list.
 * @param {object[]} forecast
 * @returns {string}
 */
function formatForecast(forecast) {
  if (!forecast || forecast.length === 0) return '  - Forecast data not available.';
  return forecast
    .map(
      (f) =>
        `  - ${f.date}: ${f.temperature}°C, ${f.humidity}% humidity, ` +
        `${f.condition}${f.rainfall > 0 ? `, ${f.rainfall}mm rain` : ''}`
    )
    .join('\n');
}

/**
 * Build a structured Groq prompt for personalised crop advisory.
 *
 * @param {{
 *   land:    number,
 *   crop:    string,
 *   soil:    string,
 *   water:   string,
 * }} farmInput
 * @param {{ district: string, state: string }} location
 * @param {{ current: object, forecast: object[] }} weather
 * @returns {string}
 */
function buildCropAdvisoryPrompt(farmInput, location, weather) {
  const { land, crop, soil, water } = farmInput;
  const { district, state }         = location;
  const { current, forecast }       = weather;

  const isFallback = current?.isFallback ? ' (estimated — live data unavailable)' : '';

  return `You are KrishiMitra, a senior agricultural advisor specialising in Indian farming conditions.
Your advice must be practical, localised, and immediately actionable for a smallholder farmer.

═══════════════════════════════════════
FARMER PROFILE
═══════════════════════════════════════
- Land Size    : ${land} acre(s)
- Crop         : ${crop}
- Soil Type    : ${soil}
- Water Source : ${water} availability

═══════════════════════════════════════
LOCATION
═══════════════════════════════════════
- District : ${district}
- State    : ${state}

═══════════════════════════════════════
CURRENT WEATHER${isFallback}
═══════════════════════════════════════
- Temperature : ${current.temperature}°C (feels like ${current.feelsLike}°C)
- Humidity    : ${current.humidity}%
- Condition   : ${current.condition}
- Wind Speed  : ${current.windSpeed} m/s
- Rainfall    : ${current.rainfall} mm/h

5-DAY FORECAST:
${formatForecast(forecast)}

═══════════════════════════════════════
ADVISORY TASKS — answer all 6 sections
═══════════════════════════════════════

1. **STEP-BY-STEP FARMING PLAN**
   Provide a clear, ordered plan from soil preparation → sowing → harvesting.
   Tailor every step to the above soil type, water availability, and current weather.

2. **FERTILIZER SCHEDULE**
   List recommended fertilizers with:
   - Exact quantity per acre
   - Application timing (stage of crop growth)
   - Application method (broadcasting, drip, foliar, etc.)

3. **PESTICIDE & DISEASE MANAGEMENT**
   List common pests/diseases for this crop in this region.
   For each: name, symptoms, recommended pesticide/bio-control, dosage per acre, and when to apply.
   Only recommend pesticides if conditions warrant them.

4. **IRRIGATION SCHEDULE**
   Provide a week-by-week irrigation guide based on:
   - Water availability (${water})
   - Current temperature & humidity
   - Crop growth stage

5. **WEATHER-BASED RISK ALERTS**
   Identify any immediate risks based on the weather data above (heat stress, flood risk, frost, drought, pest pressure, etc.).
   Provide specific mitigation actions for each risk.

6. **WEEKLY ACTION TIMELINE** (next 4 weeks)
   A simple table:
   | Week | Key Actions |
   |------|-------------|
   | Week 1 | ... |
   | Week 2 | ... |
   | Week 3 | ... |
   | Week 4 | ... |

═══════════════════════════════════════
OUTPUT RULES
═══════════════════════════════════════
- Use clear headings for each section (##)
- Use bullet points inside sections
- Use simple, jargon-free English a farmer can understand
- Be specific with quantities, dates, and measurements
- Do NOT add preamble or closing remarks — start directly with Section 1
- Total response should be comprehensive but concise (600–900 words)
`;
}

module.exports = { buildCropAdvisoryPrompt };
