#!/usr/bin/env bash
# Builds the fixture repo: a tiny Node service with a Project config whose CI
# workflow runs lint, test and deploy on main, plus the shared fake gh
# (../fakes/gh) and its scenario. PR #7 was just merged; its CI run on main
# (3001) takes six polls to finish and ends green, but its deploy job is
# skipped, so nothing ships. An earlier run (3000) is already done.
set -euo pipefail

FAKE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fakes" && pwd)/gh"
[[ -f "$FAKE" ]] || { echo "fixture: shared fake gh not found at $FAKE" >&2; exit 1; }

git init -q -b main
git config user.name fixture
git config user.email fixture@example.com

mkdir -p src docs/agents .github/workflows
cat > package.json <<'JSON'
{
  "name": "notes-api",
  "version": "0.9.1",
  "private": true,
  "scripts": { "lint": "eslint .", "test": "node --test" }
}
JSON
cat > src/tags.js <<'JS'
// Tags are lowercase, trimmed and unique per note.
function normalizeTags(tags) {
  return [...new Set(tags.map((t) => t.trim().toLowerCase()).filter(Boolean))];
}
module.exports = { normalizeTags };
JS
cat > .github/workflows/ci.yml <<'YAML'
name: CI
on:
  push:
    branches: [main]
  pull_request:
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run lint
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test
      - run: npx upload-test-report
  deploy:
    needs: [lint, test]
    if: github.ref == 'refs/heads/main' && vars.DEPLOY_ENABLED == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/deploy.sh
YAML
cat > docs/agents/harness.md <<'MD'
# Harness: Project config

## Code host

- **Host**: github
- **Repo**: example-org/notes-api
- **Default branch**: main

## Pre-flight

- `npm run lint`
- `npm run test`

## CI

- `ci.yml` (CI): `lint`, `test`, `deploy`

## Merge

- **Method**: squash
- **Merging deploys**: yes

## Deploy

- **Target**: the notes-api service on the hosting provider
- **Triggered by**: the `deploy` job in `ci.yml` on push to `main`
- **Live URL**: https://notes.example.com

## Dev and sandbox

- **staging**: https://staging.notes.example.com; staging copy of the service

## Fixtures

- **Convention**: none
- **Reset**: none

## Data connectors

- none

## Issues

- **Tracker**: GitHub Issues in example-org/notes-api
- **Close convention**: `Closes #<n>` in the PR body
MD
git add -A
git commit -qm "Add tag normalization for notes (#7)"

# --- fake gh and its scenario ---
mkdir -p .fake-gh/bin .fake-gh/runs/3000 .fake-gh/runs/3001 .fake-gh/prs
cp "$FAKE" .fake-gh/bin/gh
chmod +x .fake-gh/bin/gh
echo .fake-gh/ >> .git/info/exclude
SHA="$(git rev-parse HEAD)"
printf 'example-org/notes-api\n' > .fake-gh/repo

cat > .fake-gh/prs/7.json <<JSON
{"number": 7, "title": "Add tag normalization for notes", "state": "MERGED",
 "headRefName": "add-note-tags", "baseRefName": "main", "mergeCommit": {"oid": "$SHA"},
 "url": "https://github.com/example-org/notes-api/pull/7"}
JSON

cat > .fake-gh/runs/3000/run.json <<'JSON'
{"databaseId": 3000, "workflowName": "CI", "path": ".github/workflows/ci.yml",
 "headBranch": "main", "headSha": "0000000000000000000000000000000000000000",
 "event": "push", "displayTitle": "Bump version to 0.9.0 (#6)",
 "url": "https://github.com/example-org/notes-api/actions/runs/3000"}
JSON
cat > .fake-gh/runs/3000/timeline.jsonl <<'JSONL'
{"status": "completed", "conclusion": "success", "jobs": [{"databaseId": 50, "name": "lint", "status": "completed", "conclusion": "success", "steps": []}, {"databaseId": 51, "name": "test", "status": "completed", "conclusion": "success", "steps": []}, {"databaseId": 52, "name": "deploy", "status": "completed", "conclusion": "success", "steps": []}]}
JSONL

cat > .fake-gh/runs/3001/run.json <<JSON
{"databaseId": 3001, "workflowName": "CI", "path": ".github/workflows/ci.yml",
 "headBranch": "main", "headSha": "$SHA",
 "event": "push", "displayTitle": "Add tag normalization for notes (#7)",
 "url": "https://github.com/example-org/notes-api/actions/runs/3001"}
JSON
# Steps: lint = checkout, install, lint; test = checkout, install, tests, upload report.
L_RUN='{"databaseId": 61, "name": "lint", "status": "in_progress", "conclusion": "", "steps": [{"number": 1, "name": "Checkout", "status": "completed", "conclusion": "success"}, {"number": 2, "name": "Install", "status": "in_progress", "conclusion": ""}, {"number": 3, "name": "Lint", "status": "queued", "conclusion": ""}]}'
L_OK='{"databaseId": 61, "name": "lint", "status": "completed", "conclusion": "success", "steps": [{"number": 1, "name": "Checkout", "status": "completed", "conclusion": "success"}, {"number": 2, "name": "Install", "status": "completed", "conclusion": "success"}, {"number": 3, "name": "Lint", "status": "completed", "conclusion": "success"}]}'
T_INSTALL='{"databaseId": 62, "name": "test", "status": "in_progress", "conclusion": "", "steps": [{"number": 1, "name": "Checkout", "status": "completed", "conclusion": "success"}, {"number": 2, "name": "Install", "status": "in_progress", "conclusion": ""}]}'
T_TESTS='{"databaseId": 62, "name": "test", "status": "in_progress", "conclusion": "", "steps": [{"number": 1, "name": "Checkout", "status": "completed", "conclusion": "success"}, {"number": 2, "name": "Install", "status": "completed", "conclusion": "success"}, {"number": 3, "name": "Run tests", "status": "in_progress", "conclusion": ""}]}'
T_UPLOAD='{"databaseId": 62, "name": "test", "status": "in_progress", "conclusion": "", "steps": [{"number": 1, "name": "Checkout", "status": "completed", "conclusion": "success"}, {"number": 2, "name": "Install", "status": "completed", "conclusion": "success"}, {"number": 3, "name": "Run tests", "status": "completed", "conclusion": "success"}, {"number": 4, "name": "Upload test report", "status": "in_progress", "conclusion": ""}]}'
T_OK='{"databaseId": 62, "name": "test", "status": "completed", "conclusion": "success", "steps": [{"number": 1, "name": "Checkout", "status": "completed", "conclusion": "success"}, {"number": 2, "name": "Install", "status": "completed", "conclusion": "success"}, {"number": 3, "name": "Run tests", "status": "completed", "conclusion": "success"}, {"number": 4, "name": "Upload test report", "status": "completed", "conclusion": "success"}]}'
D_Q='{"databaseId": 63, "name": "deploy", "status": "queued", "conclusion": "", "steps": []}'
D_SKIP='{"databaseId": 63, "name": "deploy", "status": "completed", "conclusion": "skipped", "steps": []}'
cat > .fake-gh/runs/3001/timeline.jsonl <<JSONL
{"status": "queued", "conclusion": "", "jobs": []}
{"status": "in_progress", "conclusion": "", "jobs": [$L_RUN, $T_INSTALL, $D_Q]}
{"status": "in_progress", "conclusion": "", "jobs": [$L_OK, $T_TESTS, $D_Q]}
{"status": "in_progress", "conclusion": "", "jobs": [$L_OK, $T_TESTS, $D_Q]}
{"status": "in_progress", "conclusion": "", "jobs": [$L_OK, $T_UPLOAD, $D_Q]}
{"status": "completed", "conclusion": "success", "jobs": [$L_OK, $T_OK, $D_SKIP]}
JSONL
