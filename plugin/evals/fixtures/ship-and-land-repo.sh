#!/usr/bin/env bash
# Builds the ship-and-land fixture repo in the current directory: a small notes
# service whose branch 11-normalize-note-tags implements issue 11 (committed
# and pushed), a Project config where merging to main deploys production, and
# the shared fake gh (../fakes/gh) with a scenario:
#
#   - the PR the agent opens gets number 12;
#   - run 4001 (CI on the PR) starts when that PR opens and passes in 3 polls;
#   - runs 4002 (CI on main) and 4003 (Deploy on main) start when it merges;
#     the deploy succeeds after 5 polls.
#
# `origin` is github.com/example-org/notes-api rewritten to a local bare repo,
# so pushes work offline; .fake-gh/bin/git is a git that works in the eval
# sandbox (case prompts tell the agent to use it). The Pre-flight scripts
# append "preflight lint" and "preflight test" to .fake-gh/calls.log, so
# graders can order them against the gh calls logged there.
#
# --checks-never-fire: ci.yml's pull_request trigger keeps a stale paths filter
# (src/**) from before the code moved to lib/, so no check runs on the PR.
set -euo pipefail

VARIANT="${1:-}"
FAKE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fakes" && pwd)/gh"
[[ -f "$FAKE" ]] || { echo "fixture: shared fake gh not found at $FAKE" >&2; exit 1; }

BRANCH=11-normalize-note-tags

git init -q -b main
git config user.name fixture
git config user.email fixture@example.com
git init -q --bare .fake-origin.git
git remote add origin https://github.com/example-org/notes-api.git
git config url."$PWD/.fake-origin.git".insteadOf https://github.com/example-org/notes-api.git
printf '.fake-origin.git/\n.fake-gh/\n' >> .git/info/exclude

mkdir -p lib scripts docs/agents .github/workflows
cat > package.json <<'JSON'
{
  "name": "notes-api",
  "version": "1.3.0",
  "private": true,
  "scripts": { "lint": "sh scripts/lint.sh", "test": "sh scripts/test.sh" }
}
JSON
cat > lib/tags.js <<'JS'
function normalizeTags(tags) {
  return tags;
}
module.exports = { normalizeTags };
JS
cat > scripts/lint.sh <<'SH'
#!/bin/sh
# Lint stand-in: offline and instant. Records that it ran.
echo "preflight lint" >> "$(cd "$(dirname "$0")/.." && pwd)/.fake-gh/calls.log"
echo "lint: 0 problems"
SH
cat > scripts/test.sh <<'SH'
#!/bin/sh
# Test stand-in: offline and instant. Records that it ran.
echo "preflight test" >> "$(cd "$(dirname "$0")/.." && pwd)/.fake-gh/calls.log"
echo "tests: 6 passed, 0 failed"
SH

if [[ "$VARIANT" == --checks-never-fire ]]; then
  PR_TRIGGER="  pull_request:
    paths: ['src/**', 'package.json']"
else
  PR_TRIGGER="  pull_request:"
fi
cat > .github/workflows/ci.yml <<YAML
name: CI
on:
  push:
    branches: [main]
$PR_TRIGGER
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run lint
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test
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
      - run: ./scripts/deploy.sh
YAML
cat > docs/agents/harness.md <<'MD'
# Harness: Project config

## Code host

- **Host**: github
- **Repo**: example-org/notes-api
- **Default branch**: main

## Pre-flight

- `sh scripts/lint.sh`
- `sh scripts/test.sh`

## CI

- `ci.yml` (CI): `lint`, `test`
- `deploy.yml` (Deploy): `deploy`

## Merge

- **Method**: squash
- **Merging deploys**: yes

## Deploy

- **Target**: the notes-api service on the hosting provider
- **Triggered by**: `deploy.yml` on push to `main`
- **Live URL**: https://notes.example.com

## Dev and sandbox

- none

## Fixtures

- **Convention**: none
- **Reset**: none

## Data connectors

- none

## Issues

- **Tracker**: GitHub Issues in example-org/notes-api
- **Close convention**: `Closes #<n>` in the PR body; GitHub closes the issue on merge to `main`
MD
git add -A
git commit -qm "Move tag code from src/ to lib/"
git push -q origin main

git switch -q -c "$BRANCH"
cat > lib/tags.js <<'JS'
// Tags are lowercase, trimmed and unique per note (issue 11).
function normalizeTags(tags) {
  return [...new Set(tags.map((t) => t.trim().toLowerCase()).filter(Boolean))];
}
module.exports = { normalizeTags };
JS
git commit -qam "Lowercase, trim and dedupe note tags"
# Pushed already: in the macOS eval sandbox a push that sends objects fails
# (the receiving git spawns the blocked /usr/bin/git), but an up-to-date push works.
git push -q -u origin "$BRANCH"
HEAD_SHA="$(git rev-parse HEAD)"
MERGE_SHA=5d1e0c4b7a9f3e2d8c6b1a0f9e8d7c6b5a4f3e2d

# --- fake gh and its scenario ---
mkdir -p .fake-gh/bin .fake-gh/runs .fake-gh/prs
cp "$FAKE" .fake-gh/bin/gh
chmod +x .fake-gh/bin/gh
# A git that works in the eval sandbox, and with pushes to the local origin.
bash "$(dirname "${BASH_SOURCE[0]}")/sandbox-git.sh" .fake-gh/bin/git
: > .fake-gh/calls.log
printf 'example-org/notes-api\n' > .fake-gh/repo
printf '12\n' > .fake-gh/next-pr

cat > .fake-gh/issues.json <<'JSON'
[{"number": 11, "title": "Normalize note tags", "state": "OPEN",
  "url": "https://github.com/example-org/notes-api/issues/11",
  "body": "Tags typed as `Work`, ` work ` and `WORK` show up as three different chips.\n\n## Acceptance criteria\n\n- [ ] Tag chips on `/notes` render in lowercase.\n- [ ] A note never shows the same tag twice (`Work` and `work` are one chip).\n"}]
JSON

# write_run <id> <workflow name> <file> <branch> <sha> <event> <title> <startsOn>
write_run() {
  mkdir -p ".fake-gh/runs/$1"
  cat > ".fake-gh/runs/$1/run.json" <<JSON
{"databaseId": $1, "workflowName": "$2", "path": ".github/workflows/$3",
 "headBranch": "$4", "headSha": "$5", "event": "$6", "displayTitle": "$7",
 "startsOn": "$8", "url": "https://github.com/example-org/notes-api/actions/runs/$1"}
JSON
}
job() { # job <id> <name> <status> <conclusion>
  printf '{"databaseId": %s, "name": "%s", "status": "%s", "conclusion": "%s", "steps": []}' "$1" "$2" "$3" "$4"
}

if [[ "$VARIANT" != --checks-never-fire ]]; then
  write_run 4001 CI ci.yml "$BRANCH" "$HEAD_SHA" pull_request "Lowercase, trim and dedupe note tags" "pr-open:$BRANCH"
  cat > .fake-gh/runs/4001/timeline.jsonl <<JSONL
{"status": "queued", "conclusion": "", "jobs": []}
{"status": "in_progress", "conclusion": "", "jobs": [$(job 41 lint in_progress ""), $(job 42 test in_progress "")]}
{"status": "completed", "conclusion": "success", "jobs": [$(job 41 lint completed success), $(job 42 test completed success)]}
JSONL
fi

write_run 4002 CI ci.yml main "$MERGE_SHA" push "Normalize note tags (#12)" "merge:$BRANCH"
cat > .fake-gh/runs/4002/timeline.jsonl <<JSONL
{"status": "queued", "conclusion": "", "jobs": []}
{"status": "in_progress", "conclusion": "", "jobs": [$(job 51 lint completed success), $(job 52 test in_progress "")]}
{"status": "completed", "conclusion": "success", "jobs": [$(job 51 lint completed success), $(job 52 test completed success)]}
JSONL

write_run 4003 Deploy deploy.yml main "$MERGE_SHA" push "Normalize note tags (#12)" "merge:$BRANCH"
D_RUN='{"databaseId": 61, "name": "deploy", "status": "in_progress", "conclusion": "", "steps": [{"number": 1, "name": "Checkout", "status": "completed", "conclusion": "success"}, {"number": 2, "name": "Deploy", "status": "in_progress", "conclusion": ""}]}'
D_OK='{"databaseId": 61, "name": "deploy", "status": "completed", "conclusion": "success", "steps": [{"number": 1, "name": "Checkout", "status": "completed", "conclusion": "success"}, {"number": 2, "name": "Deploy", "status": "completed", "conclusion": "success"}]}'
cat > .fake-gh/runs/4003/timeline.jsonl <<JSONL
{"status": "queued", "conclusion": "", "jobs": []}
{"status": "in_progress", "conclusion": "", "jobs": [$D_RUN]}
{"status": "in_progress", "conclusion": "", "jobs": [$D_RUN]}
{"status": "in_progress", "conclusion": "", "jobs": [$D_RUN]}
{"status": "completed", "conclusion": "success", "jobs": [$D_OK]}
JSONL
