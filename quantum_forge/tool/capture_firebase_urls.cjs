// Records every Firebase JS SDK URL the web build actually requests, so the
// vendored copies are the exact files the app asks for rather than the ones we
// assume it wants. The firestore service in particular is ambiguous: the plugin
// source builds `firebase-${service.name}.js`, while the compiled app contains a
// special case for `firebase-firestore-pipelines.js`.
const { spawn } = require('child_process');
const http = require('http');
const path = require('path');

const CHROME = process.env.PROBE_CHROME
  || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const PORT = 9531;
const URL = process.env.APP_URL || 'http://127.0.0.1:8202/';
const UDD = path.join(__dirname, '..', 'build', '.chrome-capture');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const getJson = (u) => new Promise((res, rej) => {
  http.get(u, (r) => { let d = ''; r.on('data', (c) => (d += c)); r.on('end', () => res(JSON.parse(d))); }).on('error', rej);
});

async function main() {
  const proc = spawn(CHROME, [
    '--headless=new', '--no-first-run', '--enable-unsafe-swiftshader',
    '--use-gl=angle', '--use-angle=swiftshader',
    `--remote-debugging-port=${PORT}`, `--user-data-dir=${UDD}`,
    '--window-size=1280,900', 'about:blank',
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
  if (!target) { proc.kill(); console.error('NO_TARGET'); process.exit(2); }

  const ws = new WebSocket(target.webSocketDebuggerUrl);
  let id = 0; const pend = new Map();
  const requested = new Map();   // url -> status
  const failed = [];

  ws.onmessage = (ev) => {
    const m = JSON.parse(ev.data);
    if (m.id && pend.has(m.id)) { pend.get(m.id)(m); pend.delete(m.id); return; }
    if (m.method === 'Network.requestWillBeSent') {
      const url = m.params?.request?.url || '';
      if (url.includes('firebasejs')) requested.set(url, 'requested');
    } else if (m.method === 'Network.loadingFailed') {
      const url = requested.get(m.params?.documentURL) || '';
      failed.push({ requestId: m.params?.requestId, error: m.params?.errorText, url });
    } else if (m.method === 'Network.responseReceived') {
      const url = m.params?.response?.url || '';
      if (url.includes('firebasejs')) requested.set(url, `HTTP ${m.params.response.status}`);
    }
  };
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
  const send = (method, params = {}) => new Promise((res) => {
    const i = ++id; pend.set(i, res); ws.send(JSON.stringify({ id: i, method, params }));
  });

  await send('Network.enable');
  await send('Page.enable');
  await send('Runtime.enable');
  await send('Page.navigate', { url: URL });
  await sleep(35000);

  ws.close(); proc.kill();

  const urls = [...requested.entries()].map(([url, status]) => ({ url, status }));
  console.log(JSON.stringify({ appUrl: URL, sdkRequests: urls, failures: failed }, null, 2));
}

main().catch((e) => { console.error('ERR', e.message); process.exit(3); });
