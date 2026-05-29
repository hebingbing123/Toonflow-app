/**
 * Scrollbar visual audit — Flutter web screenshots at desktop + mobile viewports.
 * Env: WEB_URL, OUT_DIR
 */
import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dir = dirname(fileURLToPath(import.meta.url));
const root = join(__dir, '../..');
const require = createRequire(join(root, 'scratch/package.json'));
const { chromium } = require('playwright');

const base = process.env.WEB_URL ?? 'http://127.0.0.1:5198';
const out = process.env.OUT_DIR ?? join(root, 'scratch', 'scrollbar-audit');

mkdirSync(out, { recursive: true });

const VIEWPORTS = [
  { id: 'desktop', width: 1920, height: 1080 },
  { id: 'mobile', width: 375, height: 812 },
];

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
  await page.waitForTimeout(2500);
}

async function waitForFlutter(page, maxMs = 180_000) {
  const start = Date.now();
  while (Date.now() - start < maxMs) {
    const ready = await page.evaluate(() => {
      const host = document.querySelector('flt-semantics-host');
      const p = document.querySelector('flt-semantics-placeholder');
      const canvas =
        document.querySelector('flt-glass-pane') ||
        document.querySelector('canvas');
      return Boolean(
        host?.innerText?.length ||
          p ||
          (canvas && document.querySelector('flutter-view')),
      );
    });
    if (ready) return true;
    await page.waitForTimeout(2000);
  }
  return false;
}

async function snap(page, name) {
  const meta = await page.evaluate(() => ({
    href: window.location.href,
    hostChars:
      document.querySelector('flt-semantics-host')?.innerText?.length ?? 0,
  }));
  writeFileSync(join(out, `${name}.json`), JSON.stringify(meta, null, 2));
  await page.screenshot({
    path: join(out, `${name}.png`),
    fullPage: false,
  });
  console.log(`[snap] ${name} hostChars=${meta.hostChars}`);
}

async function scrollCanvas(page, deltaY) {
  const box = await page.evaluate(() => {
    const el =
      document.querySelector('flutter-view') ||
      document.querySelector('flt-glass-pane') ||
      document.querySelector('canvas');
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return {
      x: r.left + r.width / 2,
      y: r.top + Math.min(r.height * 0.55, r.height - 40),
    };
  });
  if (!box) {
    await page.mouse.wheel(0, deltaY);
    return;
  }
  await page.mouse.move(box.x, box.y);
  for (let i = 0; i < 4; i++) {
    await page.mouse.wheel(0, deltaY);
    await page.waitForTimeout(350);
  }
}

const browser = await chromium.launch({ headless: true });

try {
  for (const vp of VIEWPORTS) {
    const page = await browser.newPage({
      viewport: { width: vp.width, height: vp.height },
      deviceScaleFactor: vp.id === 'mobile' ? 2 : 1,
    });
    await page.goto(base, {
      waitUntil: 'domcontentloaded',
      timeout: 180_000,
    });
    await page.reload({ waitUntil: 'domcontentloaded' });
    await enableA11y(page);
    if (!(await waitForFlutter(page))) {
      await snap(page, `${vp.id}-bootstrap-fail`);
      throw new Error(`Flutter not ready @ ${vp.id}`);
    }
    await page.waitForTimeout(1500);
    await snap(page, `${vp.id}-home-top`);
    await scrollCanvas(page, 480);
    await page.waitForTimeout(800);
    await snap(page, `${vp.id}-home-scrolled`);
    await page.close();
  }
  writeFileSync(
    join(out, 'result.json'),
    JSON.stringify({ ok: true, webUrl: base, out }, null, 2),
  );
  console.log('SCROLLBAR_AUDIT_OK', out);
} catch (e) {
  writeFileSync(
    join(out, 'result.json'),
    JSON.stringify({ ok: false, error: String(e.message), webUrl: base }, null, 2),
  );
  console.error('SCROLLBAR_AUDIT_FAIL', e.message);
  process.exit(1);
} finally {
  await browser.close();
}
