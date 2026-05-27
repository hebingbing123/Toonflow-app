/**
 * Playwright preflight: confirms Flutter web actually boots (semantics host).
 * Exit 0 = ready, 1 = not ready. Env: WEB_URL
 */
import { createRequire } from 'node:module';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dir = dirname(fileURLToPath(import.meta.url));
const root = join(__dir, '../..');
const require = createRequire(join(root, 'scratch/package.json'));
const { chromium } = require('playwright');

const base = process.env.WEB_URL ?? 'http://127.0.0.1:5173';
const maxMs = Number(process.env.FLUTTER_PREFLIGHT_MAX_MS ?? 120_000);

async function enableA11y(page) {
  const ok = await page.evaluate(() => {
    const p = document.querySelector('flt-semantics-placeholder');
    if (p) {
      p.focus();
      return true;
    }
    return false;
  });
  if (ok) await page.keyboard.press('Enter');
  await page.waitForTimeout(2000);
}

async function waitForSemantics(page) {
  const start = Date.now();
  while (Date.now() - start < maxMs) {
    const ready = await page.evaluate(() => {
      const host = document.querySelector('flt-semantics-host');
      const p = document.querySelector('flt-semantics-placeholder');
      return Boolean(host?.innerText?.length || p);
    });
    if (ready) return true;
    await page.waitForTimeout(1500);
  }
  return false;
}

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
try {
  await page.goto(base, { waitUntil: 'domcontentloaded', timeout: maxMs });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await enableA11y(page);
  if (await waitForSemantics(page)) {
    console.log('FLUTTER_PREFLIGHT_OK', base);
    process.exit(0);
  }
  const diag = await page.evaluate(() => ({
    href: window.location.href,
    hasFlutterView: Boolean(document.querySelector('flutter-view')),
    hasSemanticsHost: Boolean(document.querySelector('flt-semantics-host')),
    hasPlaceholder: Boolean(document.querySelector('flt-semantics-placeholder')),
  }));
  console.error('FLUTTER_PREFLIGHT_FAIL', JSON.stringify(diag));
  process.exit(1);
} catch (e) {
  console.error('FLUTTER_PREFLIGHT_ERROR', e.message);
  process.exit(1);
} finally {
  await browser.close();
}
