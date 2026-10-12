#!/usr/bin/env bash
# Builds the fixture repo in the current directory: a small Node service with
# a test script, but no git remote, no CI workflows and nothing about deploys,
# dev targets, fixtures or data connectors.
set -euo pipefail

mkdir -p src
cat > package.json <<'JSON'
{
  "name": "notes-api",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "start": "node src/server.js",
    "test": "node --test"
  }
}
JSON
cat > src/server.js <<'JS'
const http = require("node:http");
http.createServer((req, res) => res.end("ok")).listen(process.env.PORT || 3000);
JS
cat > README.md <<'MD'
# notes-api

A small notes service.
MD
git init -q -b main
git add -A
git -c user.name=fixture -c user.email=fixture@example.com commit -qm "notes-api 1.0.0"
