#!/usr/bin/env bash
# Builds the fixture repo: a tiny Node service on branch add-note-tags (PR #7)
# with a Project config, plus the shared fake gh (../fakes/gh) and its
# scenario. The PR's CI run (2001) fails: the test job's "Run tests" step fails
# on a real bug in src/tags.js (empty tags are kept), and a later "Upload
# coverage" step fails only because no coverage file was written. The first
# failing step is "Run tests", and the failure is a real defect.
set -euo pipefail

FAKE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fakes" && pwd)/gh"
[[ -f "$FAKE" ]] || { echo "fixture: shared fake gh not found at $FAKE" >&2; exit 1; }

git init -q -b main
git config user.name fixture
git config user.email fixture@example.com

mkdir -p src test docs/agents .github/workflows
cat > package.json <<'JSON'
{
  "name": "notes-api",
  "version": "0.9.1",
  "private": true,
  "scripts": { "lint": "eslint .", "test": "node --test --experimental-test-coverage" }
}
JSON
cat > .github/workflows/ci.yml <<'YAML'
name: CI
on:
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
      - run: npx upload-coverage coverage/lcov.info
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

- `ci.yml` (CI): `lint`, `test`

## Merge

- **Method**: squash
- **Merging deploys**: no

## Deploy

- none

## Dev and sandbox

- none

## Fixtures

- **Convention**: none
- **Reset**: none

## Data connectors

- none

## Issues

- **Tracker**: GitHub Issues in example-org/notes-api
- **Close convention**: `Closes #<n>` in the PR body
MD
cat > README.md <<'MD'
# notes-api

A small notes service.
MD
git add -A
git commit -qm "notes-api 0.9.1"

git switch -q -c add-note-tags
cat > src/tags.js <<'JS'
// Tags are lowercase, trimmed and unique per note.
function normalizeTags(tags) {
  return [...new Set(tags.map((t) => t.trim().toLowerCase()))];
}
module.exports = { normalizeTags };
JS
cat > test/tags.test.js <<'JS'
const test = require("node:test");
const assert = require("node:assert");
const { normalizeTags } = require("../src/tags");

test("lowercases and trims tags", () => {
  assert.deepStrictEqual(normalizeTags([" Work ", "home"]), ["work", "home"]);
});

test("removes duplicate tags", () => {
  assert.deepStrictEqual(normalizeTags(["a", "A", "a "]), ["a"]);
});

test("drops empty tags", () => {
  assert.deepStrictEqual(normalizeTags(["a", " ", ""]), ["a"]);
});
JS
git add -A
git commit -qm "Add tag normalization for notes"

# --- fake gh and its scenario ---
mkdir -p .fake-gh/bin .fake-gh/runs/2001 .fake-gh/prs
cp "$FAKE" .fake-gh/bin/gh
chmod +x .fake-gh/bin/gh
echo .fake-gh/ >> .git/info/exclude
SHA="$(git rev-parse HEAD)"
printf 'example-org/notes-api\n' > .fake-gh/repo

cat > .fake-gh/prs/7.json <<'JSON'
{"number": 7, "title": "Add tag normalization for notes", "state": "OPEN",
 "headRefName": "add-note-tags", "baseRefName": "main",
 "url": "https://github.com/example-org/notes-api/pull/7"}
JSON

cat > .fake-gh/runs/2001/run.json <<JSON
{"databaseId": 2001, "workflowName": "CI", "path": ".github/workflows/ci.yml",
 "headBranch": "add-note-tags", "headSha": "$SHA",
 "event": "pull_request", "displayTitle": "Add tag normalization for notes",
 "url": "https://github.com/example-org/notes-api/actions/runs/2001"}
JSON
L_RUN='{"databaseId": 41, "name": "lint", "status": "in_progress", "conclusion": "", "url": "https://github.com/example-org/notes-api/actions/runs/2001/job/41", "steps": [{"number": 1, "name": "Checkout", "status": "completed", "conclusion": "success"}, {"number": 2, "name": "Install", "status": "in_progress", "conclusion": ""}]}'
L_OK='{"databaseId": 41, "name": "lint", "status": "completed", "conclusion": "success", "url": "https://github.com/example-org/notes-api/actions/runs/2001/job/41", "steps": [{"number": 1, "name": "Checkout", "status": "completed", "conclusion": "success"}, {"number": 2, "name": "Install", "status": "completed", "conclusion": "success"}, {"number": 3, "name": "Lint", "status": "completed", "conclusion": "success"}]}'
T_RUN='{"databaseId": 42, "name": "test", "status": "in_progress", "conclusion": "", "url": "https://github.com/example-org/notes-api/actions/runs/2001/job/42", "steps": [{"number": 1, "name": "Checkout", "status": "completed", "conclusion": "success"}, {"number": 2, "name": "Install", "status": "completed", "conclusion": "success"}, {"number": 3, "name": "Run tests", "status": "in_progress", "conclusion": ""}]}'
T_FAIL='{"databaseId": 42, "name": "test", "status": "completed", "conclusion": "failure", "url": "https://github.com/example-org/notes-api/actions/runs/2001/job/42", "steps": [{"number": 1, "name": "Checkout", "status": "completed", "conclusion": "success"}, {"number": 2, "name": "Install", "status": "completed", "conclusion": "success"}, {"number": 3, "name": "Run tests", "status": "completed", "conclusion": "failure"}, {"number": 4, "name": "Upload coverage", "status": "completed", "conclusion": "failure"}]}'
cat > .fake-gh/runs/2001/timeline.jsonl <<JSONL
{"status": "queued", "conclusion": "", "jobs": []}
{"status": "in_progress", "conclusion": "", "jobs": [$L_RUN, $T_RUN]}
{"status": "in_progress", "conclusion": "", "jobs": [$L_OK, $T_RUN]}
{"status": "completed", "conclusion": "failure", "jobs": [$L_OK, $T_FAIL]}
JSONL
# What --log-failed prints: every line of each failed step, prefixed with job,
# step and timestamp, as the real CLI does. The delegates-before-reading-logs
# grader finds log text in the trace by these timestamps.
{
  printf 'test\tRun tests\t2026-01-01T10:02:11.0000000Z > notes-api@0.9.1 test\n'
  printf 'test\tRun tests\t2026-01-01T10:02:11.1000000Z > node --test --experimental-test-coverage\n'
  printf 'test\tRun tests\t2026-01-01T10:02:12.0000000Z ✔ lowercases and trims tags (0.8ms)\n'
  printf 'test\tRun tests\t2026-01-01T10:02:12.1000000Z ✔ removes duplicate tags (0.2ms)\n'
  printf 'test\tRun tests\t2026-01-01T10:02:12.2000000Z ✖ drops empty tags (0.9ms)\n'
  printf 'test\tRun tests\t2026-01-01T10:02:12.2100000Z   AssertionError [ERR_ASSERTION]: Expected values to be strictly deep-equal:\n'
  printf 'test\tRun tests\t2026-01-01T10:02:12.2200000Z   + actual - expected\n'
  printf "test\tRun tests\t2026-01-01T10:02:12.2300000Z     [\n"
  printf "test\tRun tests\t2026-01-01T10:02:12.2400000Z       'a',\n"
  printf "test\tRun tests\t2026-01-01T10:02:12.2500000Z   +   ''\n"
  printf "test\tRun tests\t2026-01-01T10:02:12.2600000Z     ]\n"
  printf 'test\tRun tests\t2026-01-01T10:02:12.2700000Z       at TestContext.<anonymous> (test/tags.test.js:14:10)\n'
  printf 'test\tRun tests\t2026-01-01T10:02:12.3000000Z ℹ tests 3\n'
  printf 'test\tRun tests\t2026-01-01T10:02:12.3100000Z ℹ pass 2\n'
  printf 'test\tRun tests\t2026-01-01T10:02:12.3200000Z ℹ fail 1\n'
  printf 'test\tRun tests\t2026-01-01T10:02:12.4000000Z ##[error]Process completed with exit code 1.\n'
  printf 'test\tUpload coverage\t2026-01-01T10:02:14.0000000Z Error: coverage file not found: coverage/lcov.info\n'
  printf 'test\tUpload coverage\t2026-01-01T10:02:14.1000000Z ##[error]Process completed with exit code 1.\n'
} > .fake-gh/runs/2001/log-failed.txt
