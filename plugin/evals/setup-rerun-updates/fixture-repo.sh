#!/usr/bin/env bash
# Builds the fixture repo in the current directory: a small Node service on
# GitHub with a Project config from an earlier setup run. Since then the CI
# test job was renamed from `test` to `unit-tests`; everything else in the
# config is still right, including an operator-added note under Deploy.
set -euo pipefail

mkdir -p src .github/workflows docs/agents
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
  unit-tests:
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
cat > docs/agents/harness.md <<'MD'
# Harness: Project config

The repo-specific values Harness skills read in this repo. Written by `/harness:setup-harness`; edit it directly, or re-run setup to refresh what it can detect (re-running updates this file in place).

Every value is either a real value or `none` (this repo deliberately has none). A value that is missing or `unset` is unknown: a skill that needs it stops and asks the operator to run `/harness:setup-harness`, and never guesses it.

## Code host

- **Host**: github
- **Repo**: example-org/notes-api
- **Default branch**: main

## Pre-flight

Commands that must pass before a PR is opened, run from the repo root in this order.

- `npm run lint`
- `npm run typecheck`
- `npm run test`

## CI

Workflows and their job ids, as named in the workflow files.

- `ci.yml` (CI): `lint`, `test`
- `deploy.yml` (Deploy): `deploy`

## Merge

- **Method**: squash
- **Merging deploys**: yes

## Deploy

- **Target**: the production notes-api service
- **Triggered by**: `deploy.yml` on push to main
- **Live URL**: https://notes.example.com
- **Note**: no deploys on Fridays; hold merges until Monday.

## Dev and sandbox

Targets where writes are pre-authorized (S2). Anything not listed here is treated as live.

- **staging**: https://staging.notes.example.com; shared staging copy of the service

## Fixtures

- **Convention**: JSON fixtures in `test/fixtures/`, loaded by the tests
- **Reset**: `git checkout -- test/fixtures`

## Data connectors

Systems that data-digest and gated-write reach, and how.

- none

## Issues

- **Tracker**: GitHub Issues in example-org/notes-api
- **Close convention**: `Closes #<n>` in the PR body, closed by GitHub on merge to main
MD
git init -q -b main
git add -A
git -c user.name=fixture -c user.email=fixture@example.com commit -qm "notes-api 1.0.0"
git remote add origin git@github.com:example-org/notes-api.git
git update-ref refs/remotes/origin/main HEAD
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
