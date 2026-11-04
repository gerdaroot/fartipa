import { chromium } from 'playwright-core';
import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root = pathToFileURL(join(dirname(fileURLToPath(import.meta.url)), '..') + '/').href;
const require = createRequire(root);
const L = require('./game/logic.js');

const OUT = join(fileURLToPath(root), 'tests', 'shots');
mkdirSync(OUT, { recursive: true });
const URL_ = root + 'game/index.html';
const browser = await chromium.launch({ channel: 'chrome', headless: true });
const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
const page = await ctx.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });

const t0 = Date.now();
await page.goto(URL_);
await page.waitForSelector('#btn-free');
console.log('boot ms', Date.now() - t0);
await page.waitForTimeout(300);
await page.screenshot({ path: `${OUT}/1-menu.png` });

async function stroke(points, steps = 4) {
  await page.mouse.move(points[0].x, points[0].y);
  await page.mouse.down();
  for (const p of points.slice(1)) await page.mouse.move(p.x, p.y, { steps });
  await page.mouse.up();
}

// free draw: a wavy line and a heart-ish loop with each finger size
await page.click('#btn-free');
await page.waitForTimeout(100);
const wave = (y, amp) => Array.from({ length: 40 }, (_, i) => ({ x: 30 + i * 8.5, y: y + Math.sin(i / 3) * amp }));
await page.click('.size[data-size="7"]');
await stroke(wave(180, 20));
await page.click('.size[data-size="12"]');
await stroke(wave(300, 30));
await page.click('.size[data-size="22"]');
await stroke(wave(450, 40));
await page.waitForTimeout(150);
await page.screenshot({ path: `${OUT}/2-free.png` });

// smoothing erases a part of the fat line
const before = await page.evaluate(() => document.getElementById('surface').toDataURL().length);
await page.click('#btn-smooth');
for (let k = 0; k < 4; k += 1) await stroke([{ x: 100, y: 400 }, { x: 250, y: 500 }], 12);
await page.waitForTimeout(150);
await page.screenshot({ path: `${OUT}/3-smooth.png` });
console.log('smooth changed surface:', before !== (await page.evaluate(() => document.getElementById('surface').toDataURL().length)));

// save overlay
await page.click('#btn-save');
await page.waitForTimeout(150);
console.log('save image set:', await page.evaluate(() => document.getElementById('saved-image').src.startsWith('data:image/jpeg')));
await page.screenshot({ path: `${OUT}/4-saved.png` });
await page.click('#btn-saved-close');

// levels
await page.click('#btn-back');
await page.waitForTimeout(100);
await page.click('#btn-levels');
await page.waitForTimeout(100);
await page.screenshot({ path: `${OUT}/5-levels.png` });
console.log('locked levels:', await page.$$eval('.level', (b) => b.filter((x) => x.disabled).length));

// empty finish -> 0 stars
await page.click('.level >> nth=0');
await page.click('#btn-done');
console.log('empty verdict:', await page.textContent('#result-verdict'));
await page.click('#btn-result-again');

// trace the smile for real via box mapping
const box = await page.evaluate(() => {
  const h = innerHeight, w = innerWidth, usable = h - 80 - 100, side = Math.min(w * 0.88, usable * 0.94);
  return { x: (w - side) / 2, y: 80 + (usable - side) / 2, side };
});
const fig = L.FIGURES[0];
for (const path of fig.paths) {
  await stroke(L.densify(path, 0.04).map((p) => ({ x: box.x + p.x * box.side, y: box.y + p.y * box.side })), 1);
}
await page.waitForTimeout(150);
console.log('percent:', await page.textContent('#trace-percent'));
await page.screenshot({ path: `${OUT}/6-trace.png` });
await page.click('#btn-done');
await page.waitForTimeout(150);
console.log('verdict:', await page.textContent('#result-verdict'), '|', await page.textContent('#result-score'));
console.log('next enabled:', await page.$eval('#btn-result-next', (b) => !b.disabled));
await page.screenshot({ path: `${OUT}/7-result.png` });

// next level starts, progress survives reload
await page.click('#btn-result-next');
console.log('next level:', await page.textContent('#trace-name'));
await page.reload();
await page.click('#btn-levels');
console.log('after reload stars:', await page.$eval('.level small', (s) => s.textContent), 'locked:', await page.$$eval('.level', (b) => b.filter((x) => x.disabled).length));

// performance: time a long stroke's flush cost
const perf = await page.evaluate(() => new Promise((res) => {
  let n = 0, s = performance.now(), last = s, worst = 0;
  const tick = (t) => { worst = Math.max(worst, t - last); last = t; n += 1; if (n < 60) requestAnimationFrame(tick); else res({ fps: 60000 / (t - s), worst }); };
  requestAnimationFrame(tick);
}));
console.log('idle frames', perf);
console.log('errors:', errors);
await browser.close();
