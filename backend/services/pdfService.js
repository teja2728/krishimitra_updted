'use strict';

/**
 * pdfService.js
 * Generates a formatted KrishiMitra Crop Advisory PDF using PDFKit.
 *
 * Usage:
 *   const { streamPDF } = require('./pdfService');
 *   streamPDF({ input, location, weather, plan }, res);
 *
 * Streams directly to the HTTP response — no temp files.
 */

const PDFDocument = require('pdfkit');

// ─── Brand colours ────────────────────────────────────────────────────────────
const CLR_PRIMARY    = '#00C896';   // emerald green
const CLR_ACCENT     = '#00A3FF';   // blue
const CLR_DARK       = '#0F1320';   // deep navy
const CLR_GREY       = '#64748B';   // muted text
const CLR_LIGHT_BG   = '#F0F9F5';   // faint green bg for section headers
const CLR_DIVIDER    = '#E2E8F0';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Draw a full-width horizontal rule */
function hRule(doc, { y, color = CLR_DIVIDER, thickness = 0.5 } = {}) {
  const posY = y ?? doc.y;
  doc.save()
     .strokeColor(color)
     .lineWidth(thickness)
     .moveTo(doc.page.margins.left, posY)
     .lineTo(doc.page.width - doc.page.margins.right, posY)
     .stroke()
     .restore();
}

/** Coloured section header band */
function sectionHeader(doc, title, icon = '▸') {
  doc.moveDown(0.4);

  const bannerY = doc.y;
  const bannerH = 22;
  const lm = doc.page.margins.left;
  const rm = doc.page.margins.right;
  const bw = doc.page.width - lm - rm;

  // Background band
  doc.save()
     .fillColor(CLR_LIGHT_BG)
     .rect(lm, bannerY, bw, bannerH)
     .fill()
     .restore();

  // Left accent bar
  doc.save()
     .fillColor(CLR_PRIMARY)
     .rect(lm, bannerY, 4, bannerH)
     .fill()
     .restore();

  // Title text
  doc.fillColor(CLR_DARK)
     .font('Helvetica-Bold')
     .fontSize(10)
     .text(`  ${icon}  ${title.toUpperCase()}`, lm + 10, bannerY + 6, {
       width: bw - 10, lineBreak: false,
     });

  doc.y = bannerY + bannerH + 6;
}

/** Bullet row: "Label : Value" */
function row(doc, label, value, { indent = 0 } = {}) {
  const lm = doc.page.margins.left + indent;
  doc.fillColor(CLR_GREY)
     .font('Helvetica-Bold')
     .fontSize(9)
     .text(`${label}`, lm, doc.y, { continued: true, width: 110 });

  doc.fillColor(CLR_DARK)
     .font('Helvetica')
     .fontSize(9)
     .text(`  ${value ?? '—'}`, { width: 350 });
}

/** Capitalise first letter */
function cap(str) {
  if (!str) return '—';
  return str.charAt(0).toUpperCase() + str.slice(1);
}

/** Format date/time */
function nowStr() {
  return new Date().toLocaleString('en-IN', {
    timeZone: 'Asia/Kolkata',
    dateStyle: 'medium',
    timeStyle: 'short',
  });
}

// ─── Main export ──────────────────────────────────────────────────────────────

/**
 * Stream a formatted PDF report into an HTTP response.
 *
 * @param {object} data
 * @param {object} data.input    - { land, crop, soil, water, pincode }
 * @param {object} data.location - { district, state, postOfficeName, pincode }
 * @param {object} data.weather  - { current: { temperature, humidity, condition, ... }, forecast: [] }
 * @param {string} data.plan     - Full AI advisory text
 * @param {import('express').Response} res
 */
function streamPDF(data, res) {
  const { input, location, weather, plan } = data;
  const current  = weather?.current  ?? {};
  const forecast = weather?.forecast ?? [];

  const doc = new PDFDocument({
    size:    'A4',
    margin:  50,
    info: {
      Title:    'KrishiMitra AI Crop Advisory Report',
      Author:   'KrishiMitra',
      Subject:  `${cap(input?.crop)} Advisory — ${location?.district}, ${location?.state}`,
      Keywords: 'farming, crop advisory, agriculture, KrishiMitra',
    },
  });

  // ── HTTP headers ────────────────────────────────────────────────────────────
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader(
    'Content-Disposition',
    `attachment; filename="KrishiMitra-Advisory-${(input?.crop ?? 'report').replace(/\s+/g, '-')}.pdf"`
  );

  doc.pipe(res);

  const lm = doc.page.margins.left;
  const pw = doc.page.width - lm - doc.page.margins.right;

  // ════════════════════════════════════════════════════════════════════════════
  // HEADER BAND
  // ════════════════════════════════════════════════════════════════════════════
  // Green header rectangle
  doc.save()
     .fillColor(CLR_PRIMARY)
     .rect(0, 0, doc.page.width, 90)
     .fill()
     .restore();

  // Accent blue strip at bottom of header
  doc.save()
     .fillColor(CLR_ACCENT)
     .rect(0, 84, doc.page.width, 6)
     .fill()
     .restore();

  // Logo placeholder (leaf emoji via bullet char + circle)
  doc.save()
     .fillColor('white')
     .circle(lm + 20, 45, 18)
     .fill()
     .restore();
  doc.fillColor(CLR_PRIMARY)
     .font('Helvetica-Bold')
     .fontSize(18)
     .text('🌿', lm + 10, 35);

  // Title
  doc.fillColor('white')
     .font('Helvetica-Bold')
     .fontSize(18)
     .text('KrishiMitra', lm + 50, 22, { continued: true })
     .font('Helvetica')
     .fontSize(12)
     .text('  ·  AI Crop Advisory Report');

  // Sub-line
  doc.fillColor('rgba(255,255,255,0.80)')
     .font('Helvetica')
     .fontSize(9)
     .text(`Generated: ${nowStr()}  |  ${cap(input?.crop)} in ${location?.district ?? ''}, ${location?.state ?? ''}`,
           lm + 50, 48);

  doc.y = 106;

  // ════════════════════════════════════════════════════════════════════════════
  // SECTION 1 — FARMER DETAILS
  // ════════════════════════════════════════════════════════════════════════════
  sectionHeader(doc, 'Farmer Details', '1.');
  row(doc, 'Land Size',          `${input?.land ?? '—'} acres`);
  row(doc, 'Crop',               cap(input?.crop));
  row(doc, 'Soil Type',          cap(input?.soil));
  row(doc, 'Water Availability', cap(input?.water));
  row(doc, 'Pincode',            input?.pincode ?? '—');

  // ════════════════════════════════════════════════════════════════════════════
  // SECTION 2 — LOCATION
  // ════════════════════════════════════════════════════════════════════════════
  sectionHeader(doc, 'Location Details', '2.');
  row(doc, 'District',      cap(location?.district));
  row(doc, 'State',         cap(location?.state));
  row(doc, 'Post Office',   cap(location?.postOfficeName));

  // ════════════════════════════════════════════════════════════════════════════
  // SECTION 3 — WEATHER SUMMARY
  // ════════════════════════════════════════════════════════════════════════════
  sectionHeader(doc, 'Weather Summary', '3.');
  row(doc, 'Temperature',   `${current.temperature ?? '—'}°C (feels like ${current.feelsLike ?? '—'}°C)`);
  row(doc, 'Humidity',      `${current.humidity ?? '—'}%`);
  row(doc, 'Condition',     cap(current.condition));
  row(doc, 'Wind Speed',    `${current.windSpeed ?? '—'} m/s`);
  if (current.isFallback) {
    doc.moveDown(0.3)
       .fillColor('#E67E22').font('Helvetica-Oblique').fontSize(8)
       .text('  ⚠  Weather data is estimated (live data unavailable at time of generation).', lm);
  }

  // 5-day forecast mini-table
  if (forecast.length > 0) {
    doc.moveDown(0.5)
       .fillColor(CLR_GREY).font('Helvetica-Bold').fontSize(8)
       .text('5-Day Forecast:', lm);
    doc.moveDown(0.2);

    const colW = pw / 5;
    const startX = lm;
    const headerY = doc.y;

    // Table header
    doc.save().fillColor(CLR_PRIMARY).rect(startX, headerY, pw, 16).fill().restore();
    forecast.slice(0, 5).forEach((d, i) => {
      const dateStr = (d.date || '').slice(5); // MM-DD
      doc.fillColor('white').font('Helvetica-Bold').fontSize(7.5)
         .text(dateStr, startX + i * colW + 4, headerY + 4, { width: colW - 8, align: 'center' });
    });
    doc.y = headerY + 16;

    // Table body
    const bodyY = doc.y;
    doc.save().fillColor('#EEF9F4').rect(startX, bodyY, pw, 18).fill().restore();
    forecast.slice(0, 5).forEach((d, i) => {
      doc.fillColor(CLR_DARK).font('Helvetica').fontSize(8)
         .text(`${d.temperature ?? '?'}°C  ${d.humidity ?? '?'}%`, startX + i * colW + 4, bodyY + 5,
               { width: colW - 8, align: 'center' });
    });
    doc.y = bodyY + 22;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SECTION 4 — AI FARMING PLAN (full text)
  // ════════════════════════════════════════════════════════════════════════════
  sectionHeader(doc, 'AI-Generated Farming Advisory', '4.');

  doc.moveDown(0.2);

  if (plan) {
    // Render plan line by line — style headings differently
    const lines = plan.split('\n');
    for (const rawLine of lines) {
      const line = rawLine.trimEnd();

      if (!line.trim()) { doc.moveDown(0.35); continue; }

      // Markdown-style heading: ## Heading or **Heading**
      const isH2      = /^##\s+/.test(line);
      const isBold    = /^\*\*[^*]+\*\*/.test(line) && line.trim().startsWith('**');
      const isBullet  = /^[-•*]\s+/.test(line.trim()) || /^\d+\.\s+/.test(line.trim());
      const isTable   = line.trim().startsWith('|');

      if (isH2) {
        const text = line.replace(/^##\s+/, '').replace(/\*\*/g, '');
        doc.moveDown(0.3)
           .fillColor(CLR_PRIMARY)
           .font('Helvetica-Bold')
           .fontSize(10)
           .text(text, lm, doc.y, { width: pw });
        hRule(doc, { color: CLR_PRIMARY, thickness: 0.4 });
        doc.moveDown(0.1);
        continue;
      }

      if (isBold) {
        const text = line.replace(/\*\*/g, '');
        doc.fillColor(CLR_DARK)
           .font('Helvetica-Bold')
           .fontSize(9)
           .text(text, lm, doc.y, { width: pw });
        continue;
      }

      if (isTable) {
        doc.fillColor(CLR_GREY)
           .font('Courier')
           .fontSize(7.5)
           .text(line.replace(/\|/g, '  '), lm + 10, doc.y, { width: pw - 10 });
        continue;
      }

      if (isBullet) {
        const text = line.trim().replace(/^[-•*]\s+/, '').replace(/^\d+\.\s+/, '');
        doc.fillColor(CLR_DARK)
           .font('Helvetica')
           .fontSize(9)
           .text(`•  ${text}`, lm + 12, doc.y, { width: pw - 12 });
        continue;
      }

      // Default body text
      doc.fillColor(CLR_DARK)
         .font('Helvetica')
         .fontSize(9)
         .text(line, lm, doc.y, { width: pw });
    }
  } else {
    doc.fillColor(CLR_GREY).font('Helvetica-Oblique').fontSize(9)
       .text('Advisory not available.', lm);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // FOOTER (on every page)
  // ════════════════════════════════════════════════════════════════════════════
  const totalPages = doc.bufferedPageRange?.().count ?? 1;
  const range = doc.bufferedPageRange ? doc.bufferedPageRange() : { start: 0, count: 1 };
  for (let i = range.start; i < range.start + range.count; i++) {
    doc.switchToPage(i);
    const footerY = doc.page.height - 38;

    hRule(doc, { y: footerY - 6, color: CLR_DIVIDER });

    doc.fillColor(CLR_GREY)
       .font('Helvetica')
       .fontSize(7.5)
       .text('KrishiMitra · AI-Powered Farming Advisory Platform', lm, footerY,
             { width: pw - 80, align: 'left' });

    doc.fillColor(CLR_GREY)
       .font('Helvetica')
       .fontSize(7.5)
       .text(`Page ${i - range.start + 1} of ${range.count}`,
             pw + lm - 80, footerY, { width: 80, align: 'right' });
  }

  doc.end();
}

module.exports = { streamPDF };
