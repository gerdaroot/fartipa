// Renders the app icon with the game's own surface: 1024x1024, no alpha.
import { chromium } from 'playwright-core';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const project = join(dirname(fileURLToPath(import.meta.url)), '..');
const output = join(project, 'ios', 'PoopDraw', 'Assets.xcassets', 'AppIcon.appiconset', 'icon.png');
const SIDE = 512;

const browser = await chromium.launch({ channel: 'chrome', headless: true });
const page = await browser.newPage({ viewport: { width: SIDE, height: SIDE }, deviceScaleFactor: 2 });
await page.goto(pathToFileURL(join(project, 'game', 'index.html')).href);
await page.click('#btn-free');
await page.click('.size[data-size="22"]');

const heart = Array.from({ length: 73 }, (_, i) => {
  const t = (i / 72) * Math.PI * 2;
  const x = 16 * Math.sin(t) ** 3;
  const y = 13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t);
  return { x: SIDE / 2 + (x * SIDE) / 46, y: SIDE * 0.47 - (y * SIDE) / 46 };
});
await page.mouse.move(heart[0].x, heart[0].y);
await page.mouse.down();
for (const point of heart.slice(1)) await page.mouse.move(point.x, point.y);
await page.mouse.up();
await page.waitForTimeout(200);
await page.addStyleTag({ content: '.hud, #overlay { display: none !important; }' });
await page.screenshot({ path: output, omitBackground: false });
await browser.close();
