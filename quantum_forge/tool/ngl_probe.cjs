// ============================================================================
// NGL browser probe — verifies the WebGL path in real Chrome
// ----------------------------------------------------------------------------
// The unit tests cannot see whether NGL mounts, so this drives headless Chrome
// over the DevTools protocol against the harness build and asserts the four
// things that otherwise fail silently:
//
//   1. the vendored `ngl.js` and our bridge both loaded, and WebGL exists;
//   2. the NGL container has a real layout box and its canvas was sized to
//      match — the "permanently blank 3D pane" failure mode, where the element
//      measures 898x748 while the canvas stays 0x0;
//   3. Avogadro geometry actually reached NGL, by reading back the shape summary
//      the bridge records (`spheres`, `cylinders`) and checking the frame
//      counter advanced — which proves the animation is stepping rather than
//      showing one frozen frame;
//   4. the molecule is on screen, by counting non-background pixels inside the
//      canvas rect in a real screenshot.
//
// Point 4 needs the screenshot rather than an in-page `drawImage` of the WebGL
// canvas: without `preserveDrawingBuffer` the drawing buffer is discarded after
// compositing, so a same-page readback is always black even when the render is
// perfect. Re-loading the captured PNG into a 2D canvas sidesteps that.
//
// Usage:
//     flutter build web --release -t tool/ngl_harness.dart
//     python -m http.server 8099 --directory build/web
//     node tool/ngl_probe.cjs
//
// Exits non-zero with a diagnosis, so it is usable as a gate before deploying.
// ============================================================================

const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');
const path = require('path');

const CHROME_CANDIDATES = [
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
];

const PORT = Number(process.env.PROBE_PORT || 9461);
const URL = process.env.HARNESS_URL || 'http://127.0.0.1:8099/';
const SETTLE_MS = Number(process.env.PROBE_SETTLE_MS || 25000);
const OUT =
  process.env.PROBE_SHOT || path.join(__dirname, '..', 'build', 'ngl_probe.png');
const USER_DATA_DIR = path.join(__dirname, '..', 'build', '.chrome-ngl-probe');

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function findChrome() {
  for (const candidate of CHROME_CANDIDATES) {
    if (fs.existsSync(candidate)) return candidate;
  }
  return null;
}

const getJson = (url) =>
  new Promise((resolve, reject) => {
    http
      .get(url, (res) => {
        let body = '';
        res.on('data', (chunk) => (body += chunk));
        res.on('end', () => resolve(JSON.parse(body)));
      })
      .on('error', reject);
  });

/** The in-page inventory: what loaded, what was built, what the DOM looks like. */
const INVENTORY_EXPRESSION = `(() => {
  const containers = Array.from(
    document.querySelectorAll('[id^="quantum-forge-ngl-"]')
  );
  const canvases = containers.flatMap((c) =>
    Array.from(c.querySelectorAll('canvas'))
  );
  const canvas = canvases[0] || null;
  const rect = canvas ? canvas.getBoundingClientRect() : null;
  const bridge = window.QuantumForgeNgl;

  const ancestorBoxes = [];
  let element = containers[0];
  let depth = 0;
  while (element && depth < 8) {
    const box = element.getBoundingClientRect();
    const style = getComputedStyle(element);
    ancestorBoxes.push({
      tag: element.tagName,
      id: element.id || null,
      w: Math.round(box.width),
      h: Math.round(box.height),
      clientW: element.clientWidth,
      clientH: element.clientHeight,
      display: style.display,
      position: style.position,
    });
    element = element.parentElement;
    depth++;
  }

  return JSON.stringify({
    href: location.href,
    readyState: document.readyState,
    nglGlobalPresent: typeof window.NGL !== 'undefined',
    nglStageAvailable: !!(window.NGL && window.NGL.Stage),
    nglShapeAvailable: !!(window.NGL && window.NGL.Shape),
    bridgeAvailable: !!(bridge && bridge.available),
    bridgeVersion: bridge ? bridge.version : null,
    webglSupported: (() => {
      try {
        const probe = document.createElement('canvas');
        return !!(probe.getContext('webgl2') || probe.getContext('webgl'));
      } catch (e) {
        return false;
      }
    })(),
    nglContainerCount: containers.length,
    nglCanvasCount: canvases.length,
    canvasSizes: canvases.map((c) => ({ w: c.width, h: c.height })),
    canvasRect: rect
      ? { x: rect.x, y: rect.y, w: rect.width, h: rect.height }
      : null,
    ancestorBoxes,
    load: bridge ? bridge.lastLoadInfo() : null,
    framesApplied: bridge ? bridge.frameApplyCount() : null,
    badges: bridge ? bridge.lastBadgeInfo() : null,
    badgeCalls: bridge ? bridge.badgeCallInfo() : null,
    component: bridge ? bridge.lastComponentInfo() : null,
    stage: bridge ? bridge.lastStageInfo() : null,
    bridgeError: bridge ? bridge.lastErrorInfo() : null,
    flutterViewPresent: !!document.querySelector('flutter-view'),
  });
})()`;

async function main() {
  const chrome = findChrome();
  if (!chrome) {
    console.error('NO_CHROME: set PROBE_CHROME or install Chrome');
    process.exit(2);
  }

  // Fresh profile every run. A reused profile can serve the previous build's
  // JavaScript out of Chrome's code cache, which makes a rebuilt bridge look
  // like it was never loaded — a confusing way to lose an hour.
  try {
    fs.rmSync(USER_DATA_DIR, { recursive: true, force: true });
  } catch (_) {
    /* Nothing to clear. */
  }

  // Software rendering, because the probe must run headless with no GPU.
  // `--enable-unsafe-swiftshader` is what recent Chrome requires for WebGL to
  // work at all in that configuration.
  const proc = spawn(
    chrome,
    [
      '--headless=new',
      '--no-first-run',
      '--no-default-browser-check',
      '--enable-unsafe-swiftshader',
      '--use-gl=angle',
      '--use-angle=swiftshader',
      `--remote-debugging-port=${PORT}`,
      `--user-data-dir=${USER_DATA_DIR}`,
      '--window-size=1200,1600',
      '--hide-scrollbars',
      'about:blank',
    ],
    { stdio: 'ignore' }
  );

  let target = null;
  for (let attempt = 0; attempt < 80; attempt++) {
    try {
      const list = await getJson(`http://127.0.0.1:${PORT}/json/list`);
      target = list.find((entry) => entry.type === 'page');
      if (target) break;
    } catch (_) {
      /* Chrome is not listening yet. */
    }
    await sleep(500);
  }
  if (!target) {
    console.error('NO_DEVTOOLS_TARGET');
    proc.kill();
    process.exit(2);
  }

  const ws = new WebSocket(target.webSocketDebuggerUrl);
  let messageId = 0;
  const pending = new Map();
  const consoleLines = [];
  const exceptions = [];

  ws.onmessage = (event) => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      pending.get(message.id)(message);
      pending.delete(message.id);
    } else if (message.method === 'Runtime.consoleAPICalled') {
      consoleLines.push(
        `${message.params.type}: ` +
          message.params.args.map((a) => a.value ?? a.description ?? '').join(' ')
      );
    } else if (message.method === 'Runtime.exceptionThrown') {
      exceptions.push(
        message.params.exceptionDetails?.exception?.description ||
          message.params.exceptionDetails?.text ||
          JSON.stringify(message.params)
      );
    }
  };

  await new Promise((resolve, reject) => {
    ws.onopen = resolve;
    ws.onerror = reject;
  });

  const send = (method, params = {}) =>
    new Promise((resolve) => {
      const id = ++messageId;
      pending.set(id, resolve);
      ws.send(JSON.stringify({ id, method, params }));
    });

  const evaluate = async (expression, awaitPromise = false) => {
    const result = await send('Runtime.evaluate', {
      expression,
      awaitPromise,
      returnByValue: true,
    });
    const value = result?.result?.result?.value;
    return value === undefined ? null : value;
  };

  await send('Page.enable');
  await send('Runtime.enable');

  /**
   * Navigates to `url`, waits for it to settle, then samples the bridge's
   * geometry summary repeatedly so the *set* of frames drawn can be inspected —
   * which is how "dynamic bonding re-perceives per frame" is checked from
   * outside the app.
   */
  const inspect = async (url, sampleMs) => {
    await send('Page.navigate', { url });
    await sleep(SETTLE_MS);

    const inventoryRaw = await evaluate(INVENTORY_EXPRESSION);
    const inventory = inventoryRaw ? JSON.parse(inventoryRaw) : null;

    // Sample the structure summary over time. The ticker runs a few frames per
    // second, so a couple of seconds of sampling visits every image in the path.
    const samples = [];
    const deadline = Date.now() + sampleMs;
    while (Date.now() < deadline) {
      const raw = await evaluate(
        'JSON.stringify(window.QuantumForgeNgl ? Object.assign({}, '
        + 'window.QuantumForgeNgl.lastLoadInfo(), '
        + '{ framesApplied: window.QuantumForgeNgl.frameApplyCount(), '
        + 'badges: window.QuantumForgeNgl.lastBadgeInfo() }) : null)'
      );
      if (raw && raw !== 'null') samples.push(JSON.parse(raw));
      await sleep(60);
    }

    // The canvas is animating, so a single screenshot can legitimately land in
    // the gap between removing one component and the next one rendering. Take up
    // to three and keep the brightest, rather than reporting a race as a failure.
    let pixels = null;
    for (let attempt = 0; attempt < 3; attempt++) {
      const shot = await send('Page.captureScreenshot', { format: 'png' });
      const png = shot?.result?.data || '';
      if (!png) continue;
      fs.mkdirSync(path.dirname(OUT), { recursive: true });
      fs.writeFileSync(OUT, Buffer.from(png, 'base64'));
      const attemptPixels =
        inventory?.canvasRect && inventory.canvasRect.w > 0
          ? await analysePixels(png, inventory.canvasRect)
          : null;
      if (attemptPixels && (!pixels || attemptPixels.bright > pixels.bright)) {
        pixels = attemptPixels;
      }
      if (pixels && pixels.bright > 0) break;
      await sleep(450);
    }

    return { url, inventory, pixels, samples };
  };

  /** Counts non-background pixels inside the canvas rect of a real screenshot. */
  const analysePixels = async (pngBase64, rect) => {
    const raw = await evaluate(
      `(async () => {
        const image = new Image();
        image.src = 'data:image/png;base64,${pngBase64}';
        await image.decode();
        const canvas = document.createElement('canvas');
        canvas.width = image.width;
        canvas.height = image.height;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(image, 0, 0);

        const dpr = window.devicePixelRatio || 1;
        const x = Math.max(0, Math.round(${rect.x} * dpr));
        const y = Math.max(0, Math.round(${rect.y} * dpr));
        const w = Math.max(1, Math.min(image.width - x, Math.round(${rect.w} * dpr)));
        const h = Math.max(1, Math.min(image.height - y, Math.round(${rect.h} * dpr)));
        const data = ctx.getImageData(x, y, w, h).data;

        let bright = 0;
        let midGrey = 0;   // Avogadro carbon is #7F7F7F
        const histogram = {};
        for (let i = 0; i < data.length; i += 4) {
          const r = data[i], g = data[i + 1], b = data[i + 2];
          const sum = r + g + b;
          if (sum > 90) bright++;
          if (Math.abs(r - 127) < 26 && Math.abs(g - 127) < 26 && Math.abs(b - 127) < 26) midGrey++;
          if (sum > 90) {
            const key = (r >> 5) + ',' + (g >> 5) + ',' + (b >> 5);
            histogram[key] = (histogram[key] || 0) + 1;
          }
        }
        const top = Object.entries(histogram)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 6)
          .map(([k, v]) => ({ rgbBucket: k, count: v }));
        return JSON.stringify({
          total: data.length / 4,
          bright,
          brightFraction: bright / (data.length / 4),
          midGrey,
          topColorBuckets: top,
        });
      })()`,
      true
    );
    return raw ? JSON.parse(raw) : null;
  };

  // Phase 1 — Avogadro's default: bonds perceived once, from the first image.
  const staticRun = await inspect(`${URL}?fps=4`, 1500);
  // Phase 2 — dynamic bonding: re-perceived every frame, so the C–H2 bond
  // disappears once H2 passes the 1.52 A cutoff.
  const dynamicRun = await inspect(`${URL}?dynamicBonding=1&fps=4`, 3000);

  ws.close();
  proc.kill();

  const failures = [];
  const checkInventory = (label, inventory) => {
    if (!inventory) {
      failures.push(`[${label}] page inventory returned nothing`);
      return;
    }
    if (!inventory.nglGlobalPresent) {
      failures.push(`[${label}] window.NGL is undefined — ngl.js did not load`);
    } else if (!inventory.nglStageAvailable || !inventory.nglShapeAvailable) {
      failures.push(`[${label}] window.NGL loaded but Stage/Shape are missing`);
    }
    if (!inventory.bridgeAvailable) {
      failures.push(`[${label}] window.QuantumForgeNgl is undefined`);
    }
    if (!inventory.webglSupported) {
      failures.push(`[${label}] no WebGL context in this browser configuration`);
    }
    if (inventory.nglContainerCount === 0) {
      failures.push(`[${label}] no NGL container — the view factory never ran`);
    }
    if (inventory.nglContainerCount > 0 && inventory.nglCanvasCount === 0) {
      failures.push(`[${label}] NGL container has no canvas — no stage`);
    }
    if (inventory.canvasSizes.some((s) => s.w === 0 || s.h === 0)) {
      failures.push(
        `[${label}] NGL canvas is unsized: ${JSON.stringify(inventory.canvasSizes)} ` +
          `(ancestors: ${JSON.stringify(inventory.ancestorBoxes)})`
      );
    }
    if (inventory.bridgeError) {
      failures.push(`[${label}] bridge threw: ${inventory.bridgeError}`);
    }
    if (!inventory.load) {
      failures.push(`[${label}] no structure ever reached NGL`);
    } else {
      // The harness is a 3-atom C-H homolysis, so every path must deliver three
      // atoms and a real component.
      if (inventory.load.atoms !== 3) {
        failures.push(
          `[${label}] expected 3 atoms in the structure, got ${inventory.load.atoms}`
        );
      }
      if (inventory.component && inventory.component.representations !== 1) {
        failures.push(
          `[${label}] expected exactly 1 representation on the component, ` +
            `found ${inventory.component.representations}`
        );
      }
      // Bond badges: the harness runs with them on, and its first image has two
      // bonds, so two badges must have been built as their own Shape component.
      if (!inventory.badges) {
        failures.push(
          `[${label}] no bond badges reached NGL — the badge Shape was never built`
        );
      } else if (inventory.badges.count !== 2) {
        failures.push(
          `[${label}] expected 2 bond badges for the harness's two bonds, ` +
            `built ${inventory.badges.count}`
        );
      }
      // Structure + badges. More than two would mean a badge component is being
      // leaked on every frame change rather than replaced.
      if (inventory.stage && inventory.stage.components !== 2) {
        failures.push(
          `[${label}] expected 2 stage components (structure + badges), found ` +
            `${inventory.stage.components} — badge components are leaking`
        );
      }
    }
  };

  checkInventory('static', staticRun.inventory);
  checkInventory('dynamic', dynamicRun.inventory);

  // Camera and scene parameters must actually be in force, not merely requested.
  const stageInfo = staticRun.inventory?.stage ?? null;
  if (!stageInfo) {
    failures.push('stage info unavailable — cannot verify camera settings');
  } else {
    if (stageInfo.cameraType !== 'OrthographicCamera') {
      failures.push(
        `expected an orthographic camera, stage reports '${stageInfo.cameraType}'`
      );
    }
    if (stageInfo.clipNear !== -100 || stageInfo.clipFar !== 100) {
      failures.push(
        `expected clipNear -100 / clipFar 100, stage reports ` +
          `${stageInfo.clipNear} / ${stageInfo.clipFar}`
      );
    }
    if (stageInfo.sampleLevel !== 2) {
      failures.push(
        `expected sampleLevel 2 (4x MSAA), stage reports ${stageInfo.sampleLevel}`
      );
    }
    if (stageInfo.fogNear !== 100 || stageInfo.fogFar !== 200) {
      failures.push(
        `expected the tuned depth-cueing range 100/200, stage reports ` +
          `${stageInfo.fogNear} / ${stageInfo.fogFar}`
      );
    }
    // The renderer's own context attribute, not just the requested value.
    if (stageInfo.antialiasActual === false) {
      failures.push(
        'the WebGL context was created without antialiasing, so MSAA is not ' +
          `actually on (requested ${stageInfo.antialiasRequested})`
      );
    }
    // Crispness on high-DPR displays: the backing store must be scaled by the
    // device pixel ratio, and this is the check that fails on a Retina/4K panel
    // while passing on a 1x laptop.
    if (stageInfo.pixelRatio !== null && stageInfo.devicePixelRatio !== null
        && Math.abs(stageInfo.pixelRatio - stageInfo.devicePixelRatio) > 1e-6) {
      failures.push(
        `pixelRatio ${stageInfo.pixelRatio} does not match the display's ` +
          `devicePixelRatio ${stageInfo.devicePixelRatio}`
      );
    }
    if (stageInfo.backgroundColor !== 0) {
      failures.push(
        `expected a black background (0), stage reports ${stageInfo.backgroundColor}`
      );
    }
  }

  // ── Static run: dynamic bonding off ───────────────────────────────────────
  //
  // The harness is a 3-atom C-H homolysis across 5 images. With the checkbox off
  // the path is loaded once as a multi-model SDF and scrubbed, so:
  //   * exactly one structure load happens (loadSeq stays 1) — the point of the
  //     trajectory path, and what an XYZ join was trying to achieve;
  //   * the bond set is the first image's, constant at 2;
  //   * frames are applied repeatedly, i.e. the animation is really stepping.
  const staticSeqs = new Set(staticRun.samples.map((s) => s.seq));
  const staticBonds = new Set(staticRun.samples.map((s) => s.bonds));
  if (staticRun.samples.length === 0) {
    failures.push('[static] no structure samples collected');
  } else {
    if (staticBonds.size !== 1 || !staticBonds.has(2)) {
      failures.push(
        `[static] bonds must stay fixed at the first image's 2, saw ` +
          `${[...staticBonds].join(', ')}`
      );
    }
    if (staticSeqs.size !== 1 || !staticSeqs.has(1)) {
      failures.push(
        `[static] expected exactly 1 structure load for a trajectory, saw ` +
          `load sequence(s) ${[...staticSeqs].join(', ')} — the path is being ` +
          're-parsed per frame instead of scrubbed'
      );
    }
    const last = staticRun.samples[staticRun.samples.length - 1];
    if (last.frameCount !== 5) {
      failures.push(
        `[static] expected a 5-frame trajectory, NGL reports ${last.frameCount}`
      );
    }
    if (!last.hasPlayer) {
      failures.push(
        '[static] no trajectory player — addTrajectory() did not produce a ' +
          'trajList entry, so frames cannot be scrubbed'
      );
    }
    if (!(last.framesApplied > 1)) {
      failures.push(
        `[static] only ${last.framesApplied} frame(s) applied — the animation ` +
          'is not stepping'
      );
    }
  }

  // ── Dynamic run: dynamic bonding on ───────────────────────────────────────
  //
  // Connectivity cannot come from one model here, so the structure is re-sent
  // per frame. Two things must therefore both hold: the bond count varies as H2
  // leaves the 1.52 A cutoff, and the load sequence advances.
  const dynamicBonds = new Set(dynamicRun.samples.map((s) => s.bonds));
  const dynamicSeqs = new Set(dynamicRun.samples.map((s) => s.seq));
  if (dynamicRun.samples.length === 0) {
    failures.push('[dynamic] no structure samples collected');
  } else {
    if (dynamicBonds.size < 2) {
      failures.push(
        '[dynamic] bond count never changed across the path ' +
          `(saw only ${[...dynamicBonds].join(', ')}) — bonds are not being ` +
          're-perceived per frame'
      );
    }
    if (!dynamicBonds.has(2)) {
      failures.push('[dynamic] never saw the intact 2-bond geometry');
    }
    if (!dynamicBonds.has(1)) {
      failures.push(
        '[dynamic] never saw the broken bond — the C-H2 stretch should leave ' +
          'the 1.52 A cutoff'
      );
    }
    if (dynamicSeqs.size < 2) {
      failures.push(
        '[dynamic] the structure was never reloaded, so per-frame bonds cannot ' +
          'be reaching NGL'
      );
    }
  }

  for (const run of [staticRun, dynamicRun]) {
    if (run.pixels && run.pixels.bright === 0) {
      failures.push(`[${run.url}] canvas region is uniformly black`);
    }
  }

  console.log(
    JSON.stringify(
      {
        staticRun: {
          url: staticRun.url,
          load: staticRun.inventory?.load ?? null,
          component: staticRun.inventory?.component ?? null,
          framesApplied: staticRun.inventory?.framesApplied ?? null,
          distinctBondCounts: [...staticBonds],
          distinctLoadSequences: [...staticSeqs],
          pixels: staticRun.pixels,
        },
        dynamicRun: {
          url: dynamicRun.url,
          load: dynamicRun.inventory?.load ?? null,
          distinctBondCounts: [...dynamicBonds],
          distinctLoadSequences: [...dynamicSeqs],
          pixels: dynamicRun.pixels,
        },
        stage: staticRun.inventory?.stage ?? null,
        canvas: {
          sizes: staticRun.inventory?.canvasSizes ?? null,
          rect: staticRun.inventory?.canvasRect ?? null,
        },
        uncaughtExceptions: exceptions,
        consoleLines: consoleLines.slice(0, 30),
        screenshot: OUT,
        failures,
      },
      null,
      2
    )
  );

  process.exit(failures.length === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error('PROBE_ERROR', error && error.message);
  process.exit(3);
});
