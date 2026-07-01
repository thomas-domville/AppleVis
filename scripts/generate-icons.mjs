/**
 * Generates the three adaptive iOS app icon variants:
 *   app-icon.png        — light mode  (blue bg, white mark)
 *   app-icon-dark.png   — dark mode   (deep navy bg, white mark)
 *   app-icon-tinted.png — tinted mode (white bg, dark mark — iOS recolors this)
 *
 * The mark is three triangular wedges sharing a common right-side tip,
 * forming a right-pointing chevron that reflects the AppleVis brand mark.
 *
 * Run with: node scripts/generate-icons.mjs
 */

import { PNG } from 'pngjs';
import { writeFileSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR   = join(__dirname, '..', 'assets', 'icons');
const SIZE      = 1024;

// ─── Geometry ─────────────────────────────────────────────────────────────────
//
// Three triangular bars, each a filled triangle with vertices:
//   left-top, left-bottom, right-tip
//
// All share the same right-tip at (710, 512) — the chevron's point.
//
//  Icon canvas 1024 × 1024 (y increases downward)
//
//  Bar 1 — upper bar of the top arm  (85 px tall on left edge)
//  Bar 2 — lower bar of the top arm  (90 px tall on left edge, gap of 35 px above)
//  Bar 3 — the single lower arm      (205 px tall on left edge, gap of 50 px above)
//
//  Overall bounding box: x [310, 710]  y [280, 745] → centered in 1024×1024
//
const BARS = [
  { ax: 310, ay: 280,  bx: 310, by: 365,  cx: 710, cy: 512 }, // top bar
  { ax: 310, ay: 400,  bx: 310, by: 490,  cx: 710, cy: 512 }, // middle bar
  { ax: 310, ay: 540,  bx: 310, by: 745,  cx: 710, cy: 512 }, // lower arm
];

// ─── Colour variants ──────────────────────────────────────────────────────────

const ICONS = [
  { file: 'app-icon.png',        bg: '#0A84FF', fg: '#FFFFFF' }, // light
  { file: 'app-icon-dark.png',   bg: '#0A1628', fg: '#FFFFFF' }, // dark
  { file: 'app-icon-tinted.png', bg: '#FFFFFF', fg: '#1D1D1F' }, // tinted
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

function hexToRgb(hex) {
  const h = hex.replace('#', '');
  return [
    parseInt(h.slice(0, 2), 16),
    parseInt(h.slice(2, 4), 16),
    parseInt(h.slice(4, 6), 16),
  ];
}

// Returns a positive, negative, or zero value indicating which side of the
// line AB the point P falls on. Used for triangle membership tests.
function edgeSign(px, py, ax, ay, bx, by) {
  return (px - bx) * (ay - by) - (ax - bx) * (py - by);
}

function inTriangle(px, py, { ax, ay, bx, by, cx, cy }) {
  const d1 = edgeSign(px, py, ax, ay, bx, by);
  const d2 = edgeSign(px, py, bx, by, cx, cy);
  const d3 = edgeSign(px, py, cx, cy, ax, ay);
  const hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
  const hasPos = d1 > 0 || d2 > 0 || d3 > 0;
  return !(hasNeg && hasPos);
}

// ─── Generator ────────────────────────────────────────────────────────────────

function generateIcon(bgHex, fgHex, filename) {
  const png = new PNG({ width: SIZE, height: SIZE, filterType: -1 });
  const [br, bg, bb] = hexToRgb(bgHex);
  const [fr, fg, fb] = hexToRgb(fgHex);

  // Fill background
  for (let i = 0; i < SIZE * SIZE; i++) {
    const idx        = i * 4;
    png.data[idx]    = br;
    png.data[idx + 1] = bg;
    png.data[idx + 2] = bb;
    png.data[idx + 3] = 255;
  }

  // Paint each bar (scanline over bounding box, test each pixel)
  for (const bar of BARS) {
    const minX = Math.max(0,        Math.min(bar.ax, bar.bx, bar.cx));
    const maxX = Math.min(SIZE - 1, Math.max(bar.ax, bar.bx, bar.cx));
    const minY = Math.max(0,        Math.min(bar.ay, bar.by, bar.cy));
    const maxY = Math.min(SIZE - 1, Math.max(bar.ay, bar.by, bar.cy));

    for (let y = minY; y <= maxY; y++) {
      for (let x = minX; x <= maxX; x++) {
        if (inTriangle(x, y, bar)) {
          const idx        = (SIZE * y + x) * 4;
          png.data[idx]    = fr;
          png.data[idx + 1] = fg;
          png.data[idx + 2] = fb;
          png.data[idx + 3] = 255;
        }
      }
    }
  }

  writeFileSync(join(OUT_DIR, filename), PNG.sync.write(png));
  console.log(`  ✓  ${filename}`);
}

// ─── Run ──────────────────────────────────────────────────────────────────────

mkdirSync(OUT_DIR, { recursive: true });
console.log('\nGenerating AppleVis adaptive icons…\n');

for (const { file, bg, fg } of ICONS) {
  generateIcon(bg, fg, file);
}

console.log('\nDone. Update app.json to reference app-icon-dark.png and app-icon-tinted.png.');
