// Proves that workspace state survives a browser refresh.
//
// The reported bug: nothing persisted. Every read went through
// `shared_preferences`, whose plugin channel is never registered in this web
// build, so each call threw
//
//   MissingPluginException(No implementation found for method getAll on channel
//     plugins.flutter.io/shared_preferences)
//
// and every provider silently fell back to its defaults — the console carried
// one of those exceptions per provider on every page load. Storage now goes
// through `AppStorage`, which talks to `localStorage` directly.
//
// This drives the real release build and checks both halves of the round trip
// through the app's own UI, not by calling the store itself:
//
//   1. Cold load with a fresh profile. Assert the plugin exception is gone.
//   2. Type into the "Hugging Face API Token" field (which persists through
//      `QuantumSettingsNotifier`), then read `localStorage.qs_hf_token`. That is
//      the WRITE path, driven by a real click and real keystrokes.
//   3. Reload the page. Assert the stored value is still there *and* that the
//      app rebuilt the field with it. That is the READ path — the actual
//      "survives a refresh" requirement.
//   4. Seed a light theme into storage, reload, and measure the page. A separate
//      provider, and a different kind of evidence: the rendered pixels change,
//      so the restore is visible rather than merely present in storage.
//
// The DOM targets come from Flutter's semantics tree (assistive tech has to be
// switched on for Flutter to build it), which is why `enableSemantics` exists:
// it gives real, addressable elements for a canvas-rendered UI. Enabling it does
// not affect persistence.
const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');
const path = require('path');

const CHROME = process.env.PROBE_CHROME
  || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const PORT = Number(process.env.PERSIST_DEBUG_PORT || 9531);
const URL = process.env.APP_URL || 'http://127.0.0.1:8202/';
const OUT_DIR = path.join(__dirname, '..', 'build');
const SETTLE_MS = Number(process.env.PERSIST_SETTLE_MS || 25000);
const UDD = path.join(OUT_DIR, '.chrome-persist');

const TOKEN_LABEL = 'Hugging Face API Token';
const TOKEN_KEY = 'qs_hf_token';
const THEME_KEY = 'qf_theme_id';
const THEME_VALUE = 'scientific_light'; // scaffold #F5F7FA — unambiguously light.
const TOKEN_VALUE = 'qf-persist-probe-token';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const getJson = (u) => new Promise((res, rej) => {
  http.get(u, (r) => { let d = ''; r.on('data', (c) => (d += c)); r.on('end', () => res(JSON.parse(d))); }).on('error', rej);
});

async function main() {
  try { fs.rmSync(UDD, { recursive: true, force: true }); } catch (_) {}

  const proc = spawn(CHROME, [
    '--headless=new', '--no-first-run', '--no-default-browser-check',
    '--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader',
    `--remote-debugging-port=${PORT}`, `--user-data-dir=${UDD}`,
    '--window-size=1280,900', '--hide-scrollbars', 'about:blank',
  ], { stdio: 'ignore' });

  let target = null;
  for (let i = 0; i < 80; i++) {
    try {
      const list = await getJson(`http://127.0.0.1:${PORT}/json/list`);
      target = list.find((x) => x.type === 'page');
      if (target) break;
    } catch (_) {}
    await sleep(500);
  }
  if (!target) { proc.kill(); throw new Error('no devtools target'); }

  const ws = new WebSocket(target.webSocketDebuggerUrl);
  let id = 0; const pend = new Map(); const consoleLines = []; const exceptions = [];
  ws.onmessage = (ev) => {
    const m = JSON.parse(ev.data);
    if (m.id && pend.has(m.id)) { pend.get(m.id)(m); pend.delete(m.id); }
    else if (m.method === 'Runtime.consoleAPICalled') {
      consoleLines.push(m.params.args.map((a) => a.value ?? a.description ?? '').join(' '));
    } else if (m.method === 'Runtime.exceptionThrown') {
      exceptions.push(m.params.exceptionDetails?.exception?.description
        || m.params.exceptionDetails?.text || 'exception');
    }
  };
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
  const send = (method, params = {}) => new Promise((res) => {
    const i = ++id; pend.set(i, res); ws.send(JSON.stringify({ id: i, method, params }));
  });
  const evaluate = async (expression, awaitPromise = false) => {
    const r = await send('Runtime.evaluate', { expression, awaitPromise, returnByValue: true });
    const v = r?.result?.result?.value;
    return v === undefined ? null : (typeof v === 'string' ? JSON.parse(v) : v);
  };

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Network.enable');

  // ── helpers ────────────────────────────────────────────────────────────────
  /** Flutter builds no DOM for a canvas UI until assistive tech shows up. */
  async function enableSemantics() {
    await evaluate(`(() => {
      const p = document.querySelector('flt-semantics-placeholder');
      if (p) { p.click(); return JSON.stringify('clicked'); }
      return JSON.stringify('absent');
    })()`);
    await sleep(2500);
  }

  /** Rect of the persisted text field, addressed by its semantics label. */
  async function tokenField() {
    return evaluate(`(() => {
      const el = document.querySelector('input[aria-label=${JSON.stringify(TOKEN_LABEL)}]')
        || [...document.querySelectorAll('input')].find(
             (e) => (e.getAttribute('aria-label') || '') === ${JSON.stringify(TOKEN_LABEL)});
      if (!el) return JSON.stringify(null);
      const r = el.getBoundingClientRect();
      // Flutter mirrors the editing value into this semantic element only while
      // it is the active edit target, so .value can read empty on an unfocused
      // field that nonetheless holds text. Report every carrier and let the
      // assertions prefer the focused read.
      return JSON.stringify({
        x: r.x, y: r.y, w: r.width, h: r.height,
        value: el.value,
        ariaValueText: el.getAttribute('aria-valuetext'),
        ariaValueNow: el.getAttribute('aria-valuenow'),
        tag: el.tagName,
      });
    })()`);
  }

  /** Clicks the field and reads it back, i.e. what a user would see in it. */
  async function readFocusedValue() {
    const field = await tokenField();
    if (!field) return { field: null, value: null };
    await click(Math.round(field.x + field.w / 2), Math.round(field.y + field.h / 2));
    const focused = await tokenField();
    return { field: focused, value: focused?.value ?? field.value ?? null };
  }

  async function click(x, y) {
    for (const type of ['mousePressed', 'mouseReleased']) {
      await send('Input.dispatchMouseEvent', {
        type, x, y, button: 'left', buttons: type === 'mousePressed' ? 1 : 0, clickCount: 1,
      });
    }
    await sleep(500);
  }

  /** Types real text into the focused field, character by character. */
  async function typeText(text) {
    for (const ch of text) {
      await send('Input.dispatchKeyEvent', { type: 'keyDown', text: ch, unmodifiedText: ch, key: ch });
      await send('Input.dispatchKeyEvent', { type: 'keyUp', key: ch });
    }
    await sleep(600);
  }

  async function storage() {
    return evaluate(`JSON.stringify({
      token: window.localStorage.getItem(${JSON.stringify(TOKEN_KEY)}),
      theme: window.localStorage.getItem(${JSON.stringify(THEME_KEY)}),
      keys: Object.keys(window.localStorage).sort(),
    })`);
  }

  /** Fraction of near-white pixels — a light theme scores high, dark scores ~0. */
  async function look(label) {
    const shot = await send('Page.captureScreenshot', { format: 'png' });
    const png = shot?.result?.data || '';
    if (!png) return null;
    fs.writeFileSync(path.join(OUT_DIR, `persist_${label}.png`), Buffer.from(png, 'base64'));
    return evaluate(`(async () => {
      const img = new Image();
      img.src = 'data:image/png;base64,${png}';
      await img.decode();
      const c = document.createElement('canvas');
      c.width = img.width; c.height = img.height;
      const ctx = c.getContext('2d');
      ctx.drawImage(img, 0, 0);
      const d = ctx.getImageData(0, 0, c.width, c.height).data;
      let white = 0;
      for (let i = 0; i < d.length; i += 4) {
        if (d[i] >= 235 && d[i + 1] >= 235 && d[i + 2] >= 235) white++;
      }
      return JSON.stringify({ whiteFraction: +(white / (d.length / 4)).toFixed(4) });
    })()`, true);
  }

  const reload = async () => { await send('Page.reload', { ignoreCache: false }); await sleep(SETTLE_MS); };

  // ── 1. cold load ───────────────────────────────────────────────────────────
  await send('Page.navigate', { url: URL });
  await sleep(SETTLE_MS);
  await enableSemantics();
  const baselinePixels = await look('baseline');
  const baselineStorage = await storage();
  const beforeField = await tokenField();

  // ── 2. write path: a real click and real keystrokes ────────────────────────
  let afterTyping = null;
  if (beforeField) {
    await click(Math.round(beforeField.x + beforeField.w / 2),
                Math.round(beforeField.y + beforeField.h / 2));
    await typeText(TOKEN_VALUE);
    await sleep(800); // let the notifier's chained write settle
    afterTyping = await tokenField();
  }
  const afterWriteStorage = await storage();

  // ── 3. read path: reload and see whether the app rebuilds with it ──────────
  await reload();
  await enableSemantics();
  const reloadFieldRaw = await tokenField();
  const reloaded = await readFocusedValue();
  const reloadStorage = await storage();

  // ── 4. a second provider, measured in pixels ───────────────────────────────
  await evaluate(`(() => {
    window.localStorage.setItem(${JSON.stringify(THEME_KEY)}, ${JSON.stringify(THEME_VALUE)});
    return JSON.stringify('seeded');
  })()`);
  await reload();
  const themedPixels = await look('after_theme_restore');
  const themedStorage = await storage();

  ws.close(); proc.kill();

  const result = {
    baseline: { storage: baselineStorage, tokenField: beforeField, pixels: baselinePixels },
    write: { typed: TOKEN_VALUE, fieldAfterTyping: afterTyping, storage: afterWriteStorage },
    afterReload: {
      tokenFieldUnfocused: reloadFieldRaw,
      tokenFieldFocused: reloaded.field,
      restoredIntoUi: reloaded.value,
      storage: reloadStorage,
    },
    themeRestore: { seeded: THEME_VALUE, pixels: themedPixels, storage: themedStorage },
    uncaughtExceptions: exceptions.slice(0, 6),
    consoleLines: consoleLines.filter(Boolean).slice(0, 12),
  };
  console.log(JSON.stringify(result, null, 2));

  // ── verdict ────────────────────────────────────────────────────────────────
  const failures = [];
  const pluginErrors = [...exceptions, ...consoleLines]
    .filter((s) => /MissingPluginException|shared_preferences/.test(s));
  if (pluginErrors.length) {
    failures.push(`plugin errors still present: ${JSON.stringify(pluginErrors.slice(0, 3))}`);
  }
  if (!beforeField) {
    failures.push(
      `could not find the "${TOKEN_LABEL}" field in the semantics tree — the write/read assertions did not run`
    );
  }
  if (baselineStorage?.token !== null) {
    failures.push(`fresh profile already had ${TOKEN_KEY}=${baselineStorage?.token}`);
  }
  if (afterWriteStorage?.token !== TOKEN_VALUE) {
    failures.push(
      `WRITE path: expected localStorage.${TOKEN_KEY}=${TOKEN_VALUE} after typing, got ${afterWriteStorage?.token}`
    );
  }
  if (reloadStorage?.token !== TOKEN_VALUE) {
    failures.push(
      `READ path: ${TOKEN_KEY} did not survive the reload (got ${reloadStorage?.token})`
    );
  }
  if ((reloaded.value ?? null) !== TOKEN_VALUE) {
    failures.push(
      `READ path: the app did not restore the field after reload (value=${JSON.stringify(reloaded.value)}, unfocused=${JSON.stringify(reloadFieldRaw?.value)})`
    );
  }
  if ((themedStorage?.theme ?? null) !== THEME_VALUE) {
    failures.push(`theme seed was not preserved: got ${themedStorage?.theme}`);
  }
  if (!themedPixels || !baselinePixels) {
    failures.push('missing screenshots');
  } else if (themedPixels.whiteFraction < 0.5) {
    failures.push(
      `READ path (theme): expected a light page after restoring ${THEME_VALUE}, whiteFraction=${themedPixels.whiteFraction} (dark baseline was ${baselinePixels.whiteFraction})`
    );
  }

  console.log('\nFAILURES: ' + (failures.length ? JSON.stringify(failures, null, 2) : '(none)'));
  process.exit(failures.length ? 1 : 0);
}

main().catch((e) => { console.error('ERR', e.message); process.exit(3); });
