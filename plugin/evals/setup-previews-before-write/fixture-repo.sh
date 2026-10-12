#!/usr/bin/env bash
# Builds the fixture repo in the current directory: a small Node service on
# GitHub with lint/typecheck/test scripts, a CI workflow and a deploy workflow
# that runs on push to main. Nothing about the deploy target, dev targets,
# fixtures or data connectors is in the repo.
set -euo pipefail

mkdir -p src .github/workflows
cat > package.json <<'JSON'
{
  "name": "notes-api",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "start": "node src/server.js",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit",
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
cat > .github/workflows/ci.yml <<'YAML'
name: CI

on:
  pull_request:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm run lint && npm run typecheck
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm test
YAML
cat > .github/workflows/deploy.yml <<'YAML'
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/deploy.sh production
YAML
git init -q -b main
git add -A
git -c user.name=fixture -c user.email=fixture@example.com commit -qm "notes-api 1.0.0"
git remote add origin git@github.com:example-org/notes-api.git
git update-ref refs/remotes/origin/main HEAD
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
