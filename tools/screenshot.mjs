// Takes a phone-sized screenshot of the served Flutter web build.
// Usage: node screenshot.mjs <url> <out.png>   (playwright must be installed)
import { chromium } from 'playwright';

const url = process.argv[2] || 'http://localhost:8080';
const out = process.argv[3] || 'screenshot.png';

const browser = await chromium.launch();
const page = await browser.newPage({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
  isMobile: true,
  hasTouch: true,
});
await page.goto(url, { waitUntil: 'load' });
await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60000 });
// Let map tiles and first frames settle; networkidle may never happen with tiles, so cap it.
await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
await page.waitForTimeout(5000);
await page.screenshot({ path: out });
await browser.close();
console.log('saved', out);
