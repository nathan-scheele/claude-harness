#!/usr/bin/env bash
# Builds the fixture repo: a tiny Node service on branch add-note-tags (PR #7)
# with a CI workflow but no Project config (docs/agents/harness.md), plus the
# shared fake gh (../fakes/gh) replaying a CI run in progress. run-monitor
# should stop and point at /harness:setup-harness instead of guessing the
# workflow and jobs to watch.
set -euo pipefail

FAKE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fakes" && pwd)/gh"
[[ -f "$FAKE" ]] || { echo "fixture: shared fake gh not found at $FAKE" >&2; exit 1; }

git init -q -b main
git config user.name fixture
git config user.email fixture@example.com

mkdir -p src .github/workflows
cat > package.json <<'JSON'
{
  "name": "notes-api",
  "version": "0.9.1",
  "private": true,
  "scripts": { "test": "node --test" }
}
JSON
cat > .github/workflows/ci.yml <<'YAML'
name: CI
on:
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test
YAML
cat > src/tags.js <<'JS'
// Tags are lowercase, trimmed and unique per note.
function normalizeTags(tags) {
  return [...new Set(tags.map((t) => t.trim().toLowerCase()).filter(Boolean))];
}
module.exports = { normalizeTags };
JS
git add -A
git commit -qm "notes-api 0.9.1"
git switch -q -c add-note-tags

# --- fake gh and its scenario ---
mkdir -p .fake-gh/bin .fake-gh/runs/2001 .fake-gh/prs
cp "$FAKE" .fake-gh/bin/gh
chmod +x .fake-gh/bin/gh
echo .fake-gh/ >> .git/info/exclude
printf 'example-org/notes-api\n' > .fake-gh/repo

cat > .fake-gh/prs/7.json <<'JSON'
{"number": 7, "title": "Add tag normalization for notes", "state": "OPEN",
 "headRefName": "add-note-tags", "baseRefName": "main",
 "url": "https://github.com/example-org/notes-api/pull/7"}
JSON
cat > .fake-gh/runs/2001/run.json <<'JSON'
{"databaseId": 2001, "workflowName": "CI", "path": ".github/workflows/ci.yml",
 "headBranch": "add-note-tags", "headSha": "2222222222222222222222222222222222222222",
 "event": "pull_request", "displayTitle": "Add tag normalization for notes",
 "url": "https://github.com/example-org/notes-api/actions/runs/2001"}
JSON
cat > .fake-gh/runs/2001/timeline.jsonl <<'JSONL'
{"status": "in_progress", "conclusion": "", "jobs": [{"databaseId": 42, "name": "test", "status": "in_progress", "conclusion": "", "steps": []}]}
{"status": "completed", "conclusion": "success", "jobs": [{"databaseId": 42, "name": "test", "status": "completed", "conclusion": "success", "steps": []}]}
JSONL
