// Minimal, dependency-free static server for the verification snapshot.
//
// Written because `python -m http.server` launched as a background job kept
// leaving a bound-but-not-accepting socket on the reuse port after a rebuild,
// which made probe runs fail with "window.NGL is undefined" — a page-load
// failure masquerading as a broken NGL integration. Node has been reliable here.
//
// It lives in `tool/` rather than next to the snapshot it serves, because it used
// to sit in `build/` and `flutter clean` deletes that whole tree — which would
// take the script with it and break the documented verification command.
// Usage, from `quantum_forge/`:
//
//   flutter build web --release
//   Copy-Item build\web\* build\serve -Recurse -Force
//   node tool/serve.cjs
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = process.env.SERVE_ROOT || path.join(__dirname, '..', 'build', 'serve');
const PORT = Number(process.env.SERVE_PORT || 8202);

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.sdf': 'text/plain; charset=utf-8',
  '.png': 'image/png',
  '.wasm': 'application/wasm',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.symbols': 'application/octet-stream',
};

http.createServer((request, response) => {
  const requested = decodeURIComponent((request.url || '/').split('?')[0]);
  let filePath = path.join(ROOT, requested === '/' ? 'index.html' : requested);

  // Keep every read inside the snapshot directory.
  if (!path.resolve(filePath).startsWith(path.resolve(ROOT))) {
    response.writeHead(403).end('forbidden');
    return;
  }

  fs.stat(filePath, (error, stats) => {
    if (error || stats.isDirectory()) {
      response.writeHead(404).end('not found');
      return;
    }
    response.writeHead(200, {
      'Content-Type': TYPES[path.extname(filePath)] || 'application/octet-stream',
      'Content-Length': stats.size,
      'Cache-Control': 'no-store',
    });
    fs.createReadStream(filePath).pipe(response);
  });
}).listen(PORT, '127.0.0.1', () => {
  console.log(`serving ${ROOT} at http://127.0.0.1:${PORT}/`);
});
