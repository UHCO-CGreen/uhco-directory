// server.mjs  (run with: node server.mjs)
//
// Serves index.html and transparently proxies /proxy/* → portal.opt.uh.edu/api/v1/*
// so the browser never makes cross-origin requests (no CORS issues).
//
// Credentials stay in the browser's credential inputs and are forwarded as-is.

import http  from 'node:http';
import https from 'node:https';
import fs    from 'node:fs';
import path  from 'node:path';
import { fileURLToPath } from 'node:url';

const PORT         = 3000;
const API_UPSTREAM = 'portal.opt.uh.edu';
const API_ROOT     = '/api/v1';
const __dirname    = path.dirname(fileURLToPath(import.meta.url));

const server = http.createServer((req, res) => {

  // ── Serve index.html ────────────────────────────────────────────────────
  if (req.url === '/' || req.url === '/index.html') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(fs.readFileSync(path.join(__dirname, 'index.html')));
    return;
  }

  // ── Proxy /proxy/* → portal.opt.uh.edu/api/v1/* ──────────────────────
  if (req.url.startsWith('/proxy')) {
    const apiPath = req.url.slice('/proxy'.length) || '/';  // e.g. /people?limit=10
    const targetPath = API_ROOT + apiPath;

    // Forward browser-supplied headers (Authorization, X-API-Secret, etc.)
    // but override Host so the upstream server accepts the request.
    const { host, ...forwardHeaders } = req.headers;
    forwardHeaders.host = API_UPSTREAM;

    const options = {
      hostname : API_UPSTREAM,
      path     : targetPath,
      method   : req.method,
      headers  : forwardHeaders,
    };

    const proxyReq = https.request(options, (proxyRes) => {
      res.writeHead(proxyRes.statusCode, proxyRes.headers);
      proxyRes.pipe(res);
    });

    proxyReq.on('error', (e) => {
      if (!res.headersSent) res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: `Proxy error: ${e.message}` }));
    });

    req.pipe(proxyReq);
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(PORT, () => {
  console.log(`UHCO API Explorer → http://localhost:${PORT}`);
  console.log('Open that URL in your browser, then click "Run All Examples".');
});
