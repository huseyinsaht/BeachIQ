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
// Surface startup failures in the CI log: a crash before the first frame
// otherwise just produces a blank white screenshot.
page.on('console', (m) => console.log(`[browser ${m.type()}]`, m.text()));
page.on('pageerror', (e) => console.log('[browser pageerror]', e.stack || e.message));
page.on('requestfailed', (r) =>
  console.log('[browser requestfailed]', r.url(), r.failure()?.errorText));
await page.goto(url, { waitUntil: 'load' });
await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60000 });
// Let map tiles and first frames settle; networkidle may never happen with tiles, so cap it.
await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
await page.waitForTimeout(5000);
const shot = await page.screenshot({ path: out });
await browser.close();
console.log('saved', out, `${shot.length} bytes`);
// A blank (single-colour) PNG at this size compresses to a few KB; real app
// screenshots are hundreds of KB. Fail so a blank image is not published.
if (shot.length < 30000) {
  console.error('Screenshot looks blank - the app probably failed to render.');
  process.exit(1);
}
