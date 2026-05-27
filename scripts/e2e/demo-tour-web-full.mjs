/**
 * Full product demo tour — manual Next chain + screenshots + route audit.
 * Env: WEB_URL, OUT_DIR (default scratch/demo-tour-e2e-full)
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
const out = process.env.OUT_DIR ?? join(root, 'scratch', 'demo-tour-e2e-full');
const TOTAL_STEPS = 24;
const NAV_WAIT_MS = Number(process.env.DEMO_TOUR_NAV_WAIT_MS ?? 5500);
const RAPID_CLICKS = process.env.DEMO_TOUR_RAPID_CLICKS === '1';
const RAPID_GAP_MS = Number(process.env.DEMO_TOUR_RAPID_GAP_MS ?? 180);

mkdirSync(out, { recursive: true });

/** Route matchers per tour beat (index 0..23). Same URL may repeat for sub-steps. */
const EXPECTED_ROUTES = [
  // 0 intro — projects home
  /(?:#\/)?(?:\/)?(?:\?.*)?$|^\/$/,
  // 1–2 script
  /\/projects\/\d+\/script(?:\?|$|\/)/i,
  /\/projects\/\d+\/script(?:\?|$|\/)/i,
  // 3–4 art
  /\/projects\/\d+\/art(?:\?|$|\/)/i,
  /\/projects\/\d+\/art(?:\?|$|\/)/i,
  // 5–6 assets
  /\/projects\/\d+\/assets(?:\?|$|\/)/i,
  /\/projects\/\d+\/assets(?:\?|$|\/)/i,
  // 7–10 storyboard
  /\/projects\/\d+\/storyboard/i,
  /\/projects\/\d+\/storyboard/i,
  /\/projects\/\d+\/storyboard/i,
  /\/projects\/\d+\/storyboard/i,
  // 11–12 video
  /\/projects\/\d+\/video(?:\?|$|\/)/i,
  /\/projects\/\d+\/video(?:\?|$|\/)/i,
  // 13–14 deliver
  /\/projects\/\d+\/deliver(?:\?|$|\/)/i,
  /\/projects\/\d+\/deliver(?:\?|$|\/)/i,
  // 15–16 short video / launch
  /(?:^|[?&])pane=shortvideo(?:&|$)/i,
  /(?:^|[?&])pane=shortvideo(?:&|$)/i,
  // 17 review pack
  /\/projects\/\d+\/review-pack/i,
  // 18–23 utility panes
  /(?:^|[?&])pane=tasks(?:&|$)/i,
  /(?:^|[?&])pane=quality(?:&|$)/i,
  /(?:^|[?&])pane=notifications(?:&|$)/i,
  /(?:^|[?&])pane=production(?:&|$)/i,
  /(?:^|[?&])pane=script(?:&|$)/i,
  /(?:^|[?&])pane=help(?:&|$)/i,
];

const FIND = (labels, exact = false) => `(() => {
  const host = document.querySelector('flt-semantics-host');
  if (!host) return { s: 'no_host' };
  const needles = ${JSON.stringify(labels.map((s) => s.toLowerCase()))};
  const exact = ${exact};
  const matches = [];
  host.querySelectorAll('*').forEach((el) => {
    const label = (el.getAttribute('aria-label') || '').toLowerCase();
    if (!label) return;
    const hit = exact
      ? needles.some((n) => label === n)
      : needles.some((n) => label.includes(n));
    if (hit) {
      const r = el.getBoundingClientRect();
      if (r.width > 0 && r.height > 0) {
        matches.push({ x: Math.round(r.left + r.width / 2), y: Math.round(r.top + r.height / 2), label: label.slice(0, 120) });
      }
    }
  });
  if (!matches.length) return { s: 'not_found' };
  matches.sort((a, b) => b.y - a.y || b.x - a.x);
  return { s: 'ok', ...matches[0] };
})()`;

const agentLogs = [];

function routeBlob(route) {
  const raw = route || '';
  const hashIdx = raw.indexOf('#');
  const hashPart = hashIdx >= 0 ? raw.slice(hashIdx + 1) : raw;
  const pathQuery = hashPart || raw;
  return `${raw}\n${pathQuery}`.toLowerCase();
}

function routeMatchesIndex(route, index) {
  const blob = routeBlob(route);
  if (index < 0 || index >= EXPECTED_ROUTES.length) {
    return false;
  }
  if (index === 0) {
    const home =
      /(?:#\/)?(?:\/)?(?:\?.*)?$/.test(blob) &&
      !/\/projects\//i.test(blob) &&
      !/pane=/i.test(blob);
    return home;
  }
  // Utility script pane: must not match in-project /projects/:id/script
  if (index === 22) {
    return (
      /(?:^|[?&])pane=script(?:&|$)/i.test(blob) &&
      !/\/projects\/\d+\/script/i.test(blob)
    );
  }
  return EXPECTED_ROUTES[index].test(blob);
}

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
  let a11yAttempts = 0;
  while (Date.now() - start < maxMs) {
    const state = await page.evaluate(() => {
      const host = document.querySelector('flt-semantics-host');
      const text = host?.innerText ?? '';
      return {
        hostLen: text.length,
        hasPlaceholder: Boolean(document.querySelector('flt-semantics-placeholder')),
      };
    });
    if (state.hostLen >= 80) {
      return true;
    }
    if (state.hasPlaceholder && a11yAttempts < 8) {
      await enableA11y(page);
      a11yAttempts += 1;
    }
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

function demoUiNoise(text) {
  const issues = [];
  if (/generation tasks failed|部分生成任务失败/i.test(text)) {
    issues.push('studio_failed_jobs_banner');
  }
  if (/failed to fetch/i.test(text)) {
    issues.push('help_hub_fetch_error');
  }
  return issues;
}

function parseStepCounter(text) {
  const zh = text.match(/第\s*(\d+)\s*\/\s*(\d+)\s*步/);
  if (zh) return { current: Number(zh[1]), total: Number(zh[2]) };
  const en = text.match(/step\s*(\d+)\s*of\s*(\d+)/i);
  if (en) return { current: Number(en[1]), total: Number(en[2]) };
  return null;
}

async function capture(page, tag) {
  const state = await page.evaluate(() => ({
    href: window.location.href,
    route: `${window.location.pathname}${window.location.hash}`,
  }));
  const text = await page.evaluate(
    () => document.querySelector('flt-semantics-host')?.innerText || '',
  );
  const counter = parseStepCounter(text);
  const routeOk = routeMatchesIndex(state.route, Number(tag) - 1);
  const pad = String(tag).padStart(2, '0');
  const baseName = `step-${pad}`;
  writeFileSync(
    join(out, `${baseName}.txt`),
    `TAG: ${tag}\nLOC: ${JSON.stringify(state, null, 2)}\nCOUNTER: ${JSON.stringify(counter)}\nROUTE_OK: ${routeOk}\n\n${text.slice(0, 4000)}`,
  );
  await page.screenshot({ path: join(out, `${baseName}.png`), fullPage: true });
  const uiNoise = demoUiNoise(text);
  const row = {
    tag,
    route: state.route,
    counter,
    routeOk,
    inDemo:
      /exit demo|退出演示|demo mode|step \d+ of 24|第 \d+ \/ 24 步|main line ·/i.test(
        text,
      ),
    uiNoise,
  };
  console.log(
    `[${baseName}] route=${row.route} counter=${counter ? `${counter.current}/${counter.total}` : 'n/a'} routeOk=${routeOk} demo=${row.inDemo} noise=${uiNoise.length ? uiNoise.join(',') : 'none'}`,
  );
  return row;
}

async function scrollSemanticsLabelIntoView(page, labels, exact = false) {
  await page.evaluate(
    ({ labels: needles, exact }) => {
      const host = document.querySelector('flt-semantics-host');
      if (!host) return;
      host.querySelectorAll('*').forEach((el) => {
        const label = (el.getAttribute('aria-label') || '').toLowerCase();
        if (!label) return;
        const hit = exact
          ? needles.some((n) => label === n)
          : needles.some((n) => label.includes(n));
        if (hit) {
          el.scrollIntoView({ block: 'center', inline: 'nearest' });
        }
      });
    },
    { labels: labels.map((s) => s.toLowerCase()), exact },
  );
}

async function clickLabel(page, labels, timeoutMs = 45_000, exact = false) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    await scrollSemanticsLabelIntoView(page, labels, exact);
    const r = await page.evaluate(FIND(labels, exact));
    if (r.s === 'ok') {
      await page.mouse.click(r.x, r.y);
      console.log('  click', labels[0], '@', r.x, r.y, r.label ? `(${r.label})` : '');
      return true;
    }
    if (r.s === 'no_host') await enableA11y(page);
    await page.waitForTimeout(400);
  }
  return false;
}

async function clickTourNext(page) {
  const primary = ['demo tour next step'];
  if (await clickLabel(page, primary, 12_000, true)) {
    return true;
  }
  await scrollSemanticsLabelIntoView(page, primary, true);
  if (await clickLabel(page, ['next', '下一步', 'demo tour next'], 12_000, false)) {
    return true;
  }
  const vp = page.viewportSize() ?? { width: 1440, height: 1000 };
  const x = Math.round(vp.width * 0.78);
  const y = Math.round(vp.height * 0.9);
  await page.mouse.click(x, y);
  console.log('  click fallback coords', x, y);
  return true;
}

const report = {
  mode: 'manual-next-chain',
  totalSteps: TOTAL_STEPS,
  captures: [],
  failures: [],
  agentDebugLines: [],
  startedAt: new Date().toISOString(),
};

const browser = await chromium.launch({ headless: true });
const viewportWidth = Number(process.env.DEMO_TOUR_VIEWPORT_WIDTH ?? 1440);
const viewportHeight = Number(process.env.DEMO_TOUR_VIEWPORT_HEIGHT ?? 1000);
const page = await browser.newPage({
  viewport: { width: viewportWidth, height: viewportHeight },
});

page.on('console', (msg) => {
  const t = msg.text();
  if (t.includes('AGENT_DEBUG')) {
    agentLogs.push(t);
    try {
      report.agentDebugLines.push(JSON.parse(t.replace(/^AGENT_DEBUG\s*/, '')));
    } catch {
      report.agentDebugLines.push({ raw: t });
    }
  }
});

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

  const enteredDemo = await clickLabel(
    page,
    ['try demo first', '先体验演示', 'product-login-explore-demo'],
    25_000,
  );
  if (!enteredDemo) {
    await writeBootstrapDiagnostics(page, 'demo-entry-failed.json');
    throw new Error(
      `Could not click demo entry at ${base} (viewport ${viewportWidth}x${viewportHeight}). See ${join(out, 'demo-entry-failed.json')}`,
    );
  }
  const postDemoWaitMs =
    viewportWidth < 600 ? Math.max(NAV_WAIT_MS, 8000) : 4000;
  await page.waitForTimeout(postDemoWaitMs);
  await enableA11y(page);

  let prev = await capture(page, 1);
  if (!prev.inDemo) {
    await writeBootstrapDiagnostics(page, 'demo-entry-failed.json');
    throw new Error(
      `Demo mode not active after entry at ${base} (viewport ${viewportWidth}x${viewportHeight}); route=${prev.route}. See ${join(out, 'demo-entry-failed.json')}`,
    );
  }
  report.captures.push({ expectedIndex: 0, ...prev });
  if (prev.uiNoise?.length) {
    report.failures.push({
      atClick: 0,
      reason: 'demo ui noise',
      uiNoise: prev.uiNoise,
      route: prev.route,
    });
  }

  for (let click = 1; click < TOTAL_STEPS; click++) {
    const ok = await clickTourNext(page);
    if (!ok) {
      report.failures.push({
        atClick: click,
        reason: 'Next button not found',
      });
      break;
    }
    await page.waitForTimeout(RAPID_CLICKS ? RAPID_GAP_MS : NAV_WAIT_MS);
    if (!RAPID_CLICKS) {
      await enableA11y(page);
    }
    const snap = await capture(page, click + 1);
    const expectedIndex = click;
    report.captures.push({ expectedIndex, ...snap });

    if (!snap.inDemo) {
      report.failures.push({
        atClick: click,
        reason: 'left demo mode',
        route: snap.route,
      });
    }
    if (!snap.routeOk) {
      report.failures.push({
        atClick: click,
        reason: 'route mismatch',
        expectedIndex,
        route: snap.route,
      });
    }
    if (snap.uiNoise?.length) {
      report.failures.push({
        atClick: click,
        reason: 'demo ui noise',
        uiNoise: snap.uiNoise,
        route: snap.route,
      });
    }
    if (snap.counter && snap.counter.current !== expectedIndex + 1) {
      console.warn(
        `[warn] step counter mismatch at ${click + 1}: expected ${expectedIndex + 1}, got ${snap.counter.current}`,
      );
    }
    if (prev.routeOk && snap.routeOk) {
      const prevIdx = expectedIndex - 1;
      if (prevIdx >= 0 && expectedIndex <= prevIdx) {
        report.failures.push({
          atClick: click,
          reason: 'route index did not advance',
          prevRoute: prev.route,
          route: snap.route,
        });
      }
    }
    prev = snap;
  }

  report.endedAt = new Date().toISOString();
  const hardFailures = report.failures.filter(
    (f) => f.reason !== 'left demo mode',
  );
  report.passed =
    hardFailures.length === 0 && report.captures.length >= TOTAL_STEPS;
  writeFileSync(join(out, 'full-tour-report.json'), JSON.stringify(report, null, 2));
  writeFileSync(join(out, 'agent-debug.ndjson'), agentLogs.join('\n'));

  console.log('FULL_TOUR_PASSED', report.passed);
  console.log('FAILURES', report.failures.length);
  if (report.failures.length) {
    console.log(JSON.stringify(report.failures, null, 2));
  }
  process.exit(report.passed ? 0 : 1);
} catch (e) {
  report.error = e.message;
  writeFileSync(join(out, 'full-tour-report.json'), JSON.stringify(report, null, 2));
  console.error('FAIL', e.message);
  process.exit(1);
} finally {
  await browser.close();
}
