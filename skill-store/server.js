#!/usr/bin/env node
// skill-store/server.js — Skill Store 靜態伺服器
// 用法：node skill-store/server.js
// 預設 port 3943（vault-static-server 用 3942）

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3943;
const ROOT = __dirname;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css':  'text/css',
  '.js':   'application/javascript',
  '.json': 'application/json; charset=utf-8',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.svg':  'image/svg+xml',
};

const server = http.createServer((req, res) => {
  // CORS for local dev
  res.setHeader('Access-Control-Allow-Origin', '*');

  let urlPath = req.url.split('?')[0];
  if (urlPath === '/') urlPath = '/index.html';

  // skills/[name]/icon.png → serve from parent Life-OS/skills/
  let filePath;
  if (urlPath.startsWith('/skills/')) {
    filePath = path.join(ROOT, '..', urlPath);
  } else {
    filePath = path.join(ROOT, urlPath);
  }

  // Security: must stay within Life-OS
  const lifeOsRoot = path.resolve(ROOT, '..');
  if (!filePath.startsWith(lifeOsRoot)) {
    res.writeHead(403); res.end('Forbidden'); return;
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404); res.end('Not found'); return;
    }
    const ext = path.extname(filePath);
    res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
    res.end(data);
  });
});

server.listen(PORT, () => {
  console.log(`✅ Skill Store running → http://localhost:${PORT}`);
  console.log(`   根目錄：${ROOT}`);
});
