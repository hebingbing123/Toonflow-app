/**
 * Headless Web E2E: product demo tour (no manual clicks).
 *
 * Flow: load app → enable a11y → enter demo → Next → assert script route holds.
 * Env: WEB_URL (default http://127.0.0.1:5173), OUT_DIR, DEMO_TOUR_TEST_AUTOPLAY=1
 */
import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dir = dirname(fileURLToPath(import.meta.url));
const root = join(__dir, '../..');
const require = createRequire(join(root, 'scratch/package.json'));
const { chromium } = require('playwright');
const base = process.env.WEB_URL ?? 'http://127.0.0.1:5173';
const out = process.env.OUT_DIR ?? join(root, 'scratch', 'demo-tour-e2e');
const testAutoplay = process.env.DEMO_TOUR_TEST_AUTOPLAY === '1';

mkdirSync(out, { recursive: true });

const FIND = (labels) => `(() => {
  const host = document.querySelector('flt-semantics-host');
  if (!host) return { s: 'no_host' };
  const needles = ${JSON.stringify(labels.map((s) => s.toLowerCase()))};
  const matches = [];
  host.querySelectorAll('*').forEach((el) => {
    const label = (el.getAttribute('aria-label') || '').toLowerCase();
    if (!label) return;
    if (needles.some((n) => label.includes(n))) {
      const r = el.getBoundingClientRect();
      if (r.width > 0 && r.height > 0) {
        matches.push({ x: Math.round(r.left + r.width / 2), y: Math.round(r.top + r.height / 2), label: label.slice(0, 100) });
      }
    }
  });
  if (!matches.length) return { s: 'not_found' };
  matches.sort((a, b) => b.y - a.y || b.x - a.x);
  return { s: 'ok', ...matches[0] };
})()`;

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
      const canvas = document.querySelector('flt-glass-pane') || document.querySelector('canvas');
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

async function writeBootstrapDiagnostics(page, filename = 'bootstrap-diagnostics.json') {
  const diagnostics = await page.evaluate(() => {
    const bodyText = (document.body?.innerText || '').slice(0, 1200);
    const semanticsText =
      (document.querySelector('flt-semantics-host')?.innerText || '').slice(0, 1200);
    return {
      href: window.location.href,
      title: document.title,
      hasFlutterView: Boolean(document.querySelector('flutter-view')),
      hasSemanticsHost: Boolean(document.querySelector('flt-semantics-host')),
      hasSemanticsPlaceholder: Boolean(
        document.querySelector('flt-semantics-placeholder'),
      ),
      bodyText,
      semanticsText,
    };
  });
  writeFileSync(join(out, filename), JSON.stringify(diagnostics, null, 2));
  return diagnostics;
}

async function snap(page, name) {
  const loc = await page.evaluate(() => ({
    href: window.location.href,
    route: `${window.location.pathname}${window.location.hash}`,
  }));
  const text = await page.evaluate(
    () => document.querySelector('flt-semantics-host')?.innerText || '',
  );
  writeFileSync(
    join(out, `${name}.txt`),
    `LOC: ${JSON.stringify(loc, null, 2)}\nHOST_CHARS: ${text.length}\n\n${text.slice(0, 2500)}`,
  );
  await page.screenshot({ path: join(out, `${name}.png`), fullPage: true });
  const inDemo = /exit demo|退出演示|demo mode/i.test(text);
  const onScriptStep =
    /focus:\s*script|script focus|剧本/i.test(text) ||
    /\/projects\/\d+\/script/i.test(loc.route);
  const onProjectsRoute = /\/projects\/\d+\//i.test(loc.route);
  const stillOnHomeOnly =
    /your projects|pick up where you left off|浏览示例项目/i.test(text) &&
    !onScriptStep &&
    !onProjectsRoute;
  console.log(
    `[${name}] route=${loc.route} demo=${inDemo} scriptStep=${onScriptStep} homeOnly=${stillOnHomeOnly}`,
  );
  return { loc, inDemo, onScriptStep, onProjectsRoute, stillOnHomeOnly, text };
}

async function clickLabel(page, labels, timeoutMs = 45_000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const r = await page.evaluate(FIND(labels));
    if (r.s === 'ok') {
      await page.mouse.click(r.x, r.y);
      console.log('  click', labels[0], '@', r.x, r.y);
      return true;
    }
    if (r.s === 'no_host') await enableA11y(page);
    await page.waitForTimeout(400);
  }
  console.log('  FAIL click', labels[0]);
  return false;
}

function assertNextStep(s) {
  if (!s.inDemo) return { ok: false, reason: 'demo mode not active' };
  if (!s.onProjectsRoute && !s.onScriptStep) {
    return { ok: false, reason: `expected script route, got ${s.loc.route}` };
  }
  if (s.stillOnHomeOnly) {
    return { ok: false, reason: 'UI still on projects home after Next' };
  }
  return { ok: true };
}

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
const results = { nextStep: null, autoplay: null };

try {
  await page.goto(base, { waitUntil: 'domcontentloaded', timeout: 180_000 });
  await page.reload({ waitUntil: 'domcontentloaded' });
  if (!(await waitForFlutter(page))) {
    const d = await writeBootstrapDiagnostics(page);
    throw new Error(
      `Flutter web app did not become ready at ${base}; hasFlutterView=${d.hasFlutterView}, hasSemanticsHost=${d.hasSemanticsHost}. See ${join(out, 'bootstrap-diagnostics.json')}`,
    );
  }
  await enableA11y(page);
  await snap(page, '01-loaded');

  if (!(await clickLabel(page, ['try demo first', '先体验演示', 'product-login-explore-demo'], 20_000))) {
    console.log('  (skip explore click — may already be in app shell)');
  }
  await page.waitForTimeout(4000);
  await enableA11y(page);
  const afterDemo = await snap(page, '02-after-demo');

  if (!afterDemo.inDemo && !(await clickLabel(page, ['try demo first', '先体验演示'], 15_000))) {
    results.nextStep = { ok: false, reason: 'could not enter demo mode' };
    throw new Error(results.nextStep.reason);
  }
  await page.waitForTimeout(2000);
  await enableA11y(page);

  if (
    !(await clickLabel(page, [
      'demo tour next step',
      'demo tour next',
      '下一步',
      'product-demo-tour-next',
    ]))
  ) {
    results.nextStep = { ok: false, reason: 'Next button not found' };
    throw new Error(results.nextStep.reason);
  }

  await page.waitForTimeout(2500);
  const afterNext = await snap(page, '03-after-next');
  await page.waitForTimeout(8000);
  const afterHold = await snap(page, '04-after-hold-8s');

  results.nextStep = assertNextStep(afterNext);
  if (results.nextStep.ok) {
    const hold = assertNextStep(afterHold);
    if (!hold.ok) {
      results.nextStep = { ok: false, reason: `rewound after 8s: ${hold.reason}` };
    }
  }

  if (testAutoplay) {
    await page.goto(base, { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    await enableA11y(page);
    await clickLabel(page, ['try demo first', '先体验演示'], 20_000);
    await page.waitForTimeout(3000);
    await enableA11y(page);
    const before = await page.evaluate(
      () => document.querySelector('flt-semantics-host')?.innerText || '',
    );
    if (await clickLabel(page, ['auto tour', '自动导览', 'product-demo-tour-autoplay'], 25_000)) {
      await page.waitForTimeout(1500);
      const mid = await page.evaluate(
        () => document.querySelector('flt-semantics-host')?.innerText || '',
      );
      const started = /pause tour|暂停导览/i.test(mid);
      await page.waitForTimeout(12_000);
      const after = await page.evaluate(() => ({
        text: document.querySelector('flt-semantics-host')?.innerText || '',
        route: `${window.location.pathname}${window.location.hash}`,
      }));
      const advanced =
        /第\s*([2-9]|1[0-5])\s*\/\s*15|step\s*([2-9]|1[0-5])\s*of\s*15/i.test(
          after.text,
        ) ||
        /\/projects\/\d+\/(script|art|assets|storyboard|video|deliver|review-pack)/i.test(
          after.route,
        ) ||
        /[?&]pane=(tasks|quality|notifications|shortvideo|production|script|help)/i.test(
          after.route.toLowerCase(),
        );
      results.autoplay = { ok: started && advanced, started, advanced };
      writeFileSync(join(out, 'autoplay-snippets.json'), JSON.stringify({ before, mid, after }, null, 2));
    } else {
      results.autoplay = { ok: false, reason: 'autoplay button not found' };
    }
  }

  writeFileSync(join(out, 'result.json'), JSON.stringify(results, null, 2));
  console.log('RESULT', JSON.stringify(results));

  const failed =
    !results.nextStep?.ok || (testAutoplay && !results.autoplay?.ok);
  process.exit(failed ? 1 : 0);
} catch (e) {
  console.error('FAIL', e.message);
  writeFileSync(join(out, 'result.json'), JSON.stringify({ error: e.message, results }, null, 2));
  process.exit(1);
} finally {
  await browser.close();
}
