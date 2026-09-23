// Reproduces the reported boot failure: does the app render when the Firebase JS
// SDK cannot be fetched?
//
// The reported symptom was a white screen with
//   TypeError: Failed to fetch dynamically imported module: .../firebase-app.js
// Because `main()` used to `await Firebase.initializeApp(...)` before `runApp`,
// any failure of that fetch could leave the app with no frame at all.
//
// This drives headless Chrome twice against the real web build:
//   A) with the gstatic Firebase SDK blocked  -> must still render
//   B) with it allowed                        -> must still render
// and reports the white-pixel fraction plus any uncaught errors, so "rendered"
// is measured rather than assumed.
const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');
const path = require('path');

const CHROME = process.env.PROBE_CHROME
  || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const PORT = Number(process.env.BOOT_DEBUG_PORT || 9521);
const URL = process.env.APP_URL || 'http://127.0.0.1:8202/';
const OUT_DIR = path.join(__dirname, '..', 'build');
const UDD = path.join(__dirname, '..', 'build', '.chrome-boot');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const getJson = (u) => new Promise((res, rej) => {
  http.get(u, (r) => { let d = ''; r.on('data', (c) => (d += c)); r.on('end', () => res(JSON.parse(d))); }).on('error', rej);
});

/** Fraction of near-white pixels — a blank white page scores ~1.0. */
async function whiteFraction(send, label) {
  const shot = await send('Page.captureScreenshot', { format: 'png' });
  const png = shot?.result?.data || '';
  if (!png) return null;
  fs.writeFileSync(path.join(OUT_DIR, `boot_${label}.png`), Buffer.from(png, 'base64'));

  const raw = await send('Runtime.evaluate', {
    expression: `(async () => {
      const img = new Image();
      img.src = 'data:image/png;base64,${png}';
      await img.decode();
      const c = document.createElement('canvas');
      c.width = img.width; c.height = img.height;
      const ctx = c.getContext('2d');
      ctx.drawImage(img, 0, 0);
      const d = ctx.getImageData(0, 0, c.width, c.height).data;
      let white = 0, dark = 0;
      for (let i = 0; i < d.length; i += 4) {
        const r = d[i], g = d[i + 1], b = d[i + 2];
        if (r >= 245 && g >= 245 && b >= 245) white++;
        if (r < 90 && g < 90 && b < 90) dark++;
      }
      const total = d.length / 4;
      return JSON.stringify({
        total, white, dark,
        whiteFraction: +(white / total).toFixed(4),
        darkFraction: +(dark / total).toFixed(4),
      });
    })()`,
    awaitPromise: true,
    returnByValue: true,
  });
  const value = raw?.result?.result?.value;
  return value ? JSON.parse(value) : null;
}

async function run(label, blockFirebase) {
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
  if (!target) { proc.kill(); return { label, error: 'no devtools target' }; }

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

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Network.enable');
  if (blockFirebase) {
    // Exactly the failure the user saw: the SDK module cannot be fetched.
    await send('Network.setBlockedURLs', { urls: ['*gstatic.com/firebasejs*'] });
  }

  await send('Page.navigate', { url: URL });
  await sleep(30000); // Flutter web cold start + CanvasKit

  const pixels = await whiteFraction(send, label);
  const probe = await send('Runtime.evaluate', {
    expression: `JSON.stringify({
      flutterViewPresent: !!document.querySelector('flutter-view'),
      canvases: document.querySelectorAll('canvas').length,
      nglLoaded: typeof window.NGL !== 'undefined',
      bridgeLoaded: typeof window.QuantumForgeNgl !== 'undefined',
      firebaseAppDefined: typeof window.firebase !== 'undefined',
      bodyText: (document.body.innerText || '').slice(0, 120),
    })`,
    returnByValue: true,
  });

  ws.close(); proc.kill();

  return {
    label,
    firebaseBlocked: !!blockFirebase,
    pixels,
    page: probe?.result?.result?.value ? JSON.parse(probe.result.result.value) : null,
    uncaughtExceptions: exceptions.slice(0, 6),
    consoleLines: consoleLines.filter(Boolean).slice(0, 10),
  };
}

async function main() {
  const blocked = await run('blocked', true);
  const normal = await run('normal', false);
  console.log(JSON.stringify({ blocked, normal }, null, 2));

  const failures = [];
  for (const r of [blocked, normal]) {
    if (!r.pixels) { failures.push(`[${r.label}] no screenshot`); continue; }
    if (r.pixels.whiteFraction > 0.9) {
      failures.push(
        `[${r.label}] page looks blank: whiteFraction=${r.pixels.whiteFraction}`
      );
    }
    if (r.page && !r.page.flutterViewPresent) {
      failures.push(`[${r.label}] no flutter-view in the DOM`);
    }
  }
  console.log('\nFAILURES: ' + (failures.length ? JSON.stringify(failures, null, 2) : '(none)'));
  process.exit(failures.length ? 1 : 0);
}

main().catch((e) => { console.error('ERR', e.message); process.exit(3); });
