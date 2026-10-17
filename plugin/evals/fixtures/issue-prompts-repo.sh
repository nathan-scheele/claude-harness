#!/usr/bin/env bash
# Builds the issue-prompts fixture repo in the current directory: a small notes
# service on main, a Project config whose Pre-flight commands (`make verify`,
# `sh scripts/smoke.sh`) differ from the package.json scripts (`npm run lint`,
# `npm test`, which nothing in Pre-flight runs), a read-write data connector,
# and the shared fake gh (../fakes/gh) with these issues:
#
#   40 spec (label tags-v2), parent of 41-45
#   41 CLOSED, merged on main as "Normalize note tags (#41)"
#   42 ready: blocked by 41 in the body and by native link, both closed
#   43 ready: blocked by 41 likewise; backfills tags in the production notes
#      database, so its prompt needs a hard gate
#   44 blocked: native link to 42 (open), no `## Blocked by` list
#   45 blocked: `## Blocked by` lists 43 (open), no native link
#   46 open and ready, but labelled billing, not tags-v2
#   47 CLOSED, tags-v2
#
# `origin` is github.com/example-org/notes-api rewritten to a local bare repo;
# .fake-gh/bin/git is a git that works in the eval sandbox (case prompts tell
# the agent to use it).
#
# --preflight-unset: the Project config's Pre-flight section is `unset`.
set -euo pipefail

VARIANT="${1:-}"
FAKE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fakes" && pwd)/gh"
[[ -f "$FAKE" ]] || { echo "fixture: shared fake gh not found at $FAKE" >&2; exit 1; }

git init -q -b main
git config user.name fixture
git config user.email fixture@example.com
git init -q --bare .fake-origin.git
git remote add origin https://github.com/example-org/notes-api.git
git config url."$PWD/.fake-origin.git".insteadOf https://github.com/example-org/notes-api.git
printf '.fake-origin.git/\n.fake-gh/\n' >> .git/info/exclude

mkdir -p lib scripts bin docs/agents docs/adr
cat > package.json <<'JSON'
{
  "name": "notes-api",
  "version": "1.4.0",
  "private": true,
  "scripts": { "lint": "eslint lib", "test": "node --test" }
}
JSON
cat > Makefile <<'MAKE'
verify:
	node scripts/check.js
MAKE
cat > scripts/check.js <<'JS'
// Lint and unit tests in one pass.
console.log("check: ok");
JS
cat > scripts/smoke.sh <<'SH'
#!/bin/sh
# Starts the service and checks /health.
echo "smoke: ok"
SH
cat > lib/tags.js <<'JS'
function normalizeTags(tags) {
  return tags;
}
module.exports = { normalizeTags };
JS
cat > lib/notes-store.js <<'JS'
// Reads and writes notes through the notes database.
function listNotes(db, { tag } = {}) {
  return db.query("notes", tag ? { tag } : {});
}
function updateNoteTags(db, id, tags) {
  return db.update("notes", id, { tags });
}
module.exports = { listNotes, updateNoteTags };
JS
cat > bin/notes-db <<'SH'
#!/bin/sh
# CLI for the notes database: notes-db [--target staging|production] <query|update> ...
echo "notes-db: $*"
SH
chmod +x bin/notes-db
cat > GLOSSARY.md <<'MD'
# Glossary

**Tag**: a lowercase label on a note; a note has each tag at most once.
MD
cat > docs/adr/0001-tags-stored-on-notes.md <<'MD'
# Tags are stored on the note row

Tags live in a `tags` array on each note, not a join table, because notes are read far more than tags are queried.
MD
cat > docs/agents/triage-labels.md <<'MD'
# Triage Labels

| Label in mattpocock/skills | Label in our tracker |
| -------------------------- | -------------------- |
| `needs-triage`             | `needs-triage`       |
| `needs-info`               | `needs-info`         |
| `ready-for-agent`          | `ready-for-agent`    |
| `ready-for-human`          | `ready-for-human`    |
| `wontfix`                  | `wontfix`            |
MD

if [[ "$VARIANT" == --preflight-unset ]]; then
  PREFLIGHT="- unset"
else
  PREFLIGHT='- `make verify`
- `sh scripts/smoke.sh`'
fi
cat > docs/agents/harness.md <<MD
# Harness: Project config

## Code host

- **Host**: github
- **Repo**: example-org/notes-api
- **Default branch**: main

## Pre-flight

$PREFLIGHT

## CI

- \`ci.yml\` (CI): \`verify\`

## Merge

- **Method**: squash
- **Merging deploys**: yes

## Deploy

- **Target**: the notes-api service on the hosting provider
- **Triggered by**: \`deploy.yml\` on push to \`main\`
- **Live URL**: https://notes.example.com

## Dev and sandbox

- **staging**: https://staging.notes.example.com and \`bin/notes-db --target staging\`; the staging service and its database

## Fixtures

- **Convention**: none
- **Reset**: none

## Data connectors

- **Notes database**: CLI \`bin/notes-db\`; read-write

## Issues

- **Tracker**: GitHub Issues in example-org/notes-api
- **Close convention**: \`Closes #<n>\` in the PR body; GitHub closes the issue on merge to \`main\`
MD
git add -A
git commit -qm "Notes service with tag storage"
cat > lib/tags.js <<'JS'
// Tags are lowercase, trimmed and unique per note (issue 41).
function normalizeTags(tags) {
  return [...new Set(tags.map((t) => t.trim().toLowerCase()).filter(Boolean))];
}
module.exports = { normalizeTags };
JS
git commit -qam "Normalize note tags (#41)"
git push -q origin main

# --- fake gh and its scenario ---
mkdir -p .fake-gh/bin .fake-gh/runs .fake-gh/prs
cp "$FAKE" .fake-gh/bin/gh
chmod +x .fake-gh/bin/gh
# On macOS the eval sandbox blocks the Command Line Tools behind /usr/bin/git,
# so plain git fails there. .fake-gh/bin/git runs a git that works.
for g in /opt/homebrew/bin/git /usr/local/bin/git "$(command -v git)"; do
  if [[ -x "$g" && ! ( "$(uname)" == Darwin && "$g" == /usr/bin/git ) ]]; then
    printf '#!/bin/sh\nPATH="%s:$PATH" exec "%s" "$@"\n' "$(dirname "$g")" "$g" > .fake-gh/bin/git
    chmod +x .fake-gh/bin/git
    break
  fi
done
[[ -x .fake-gh/bin/git ]] || { echo "fixture: no git usable in the eval sandbox (on macOS, install Homebrew git)" >&2; exit 1; }
: > .fake-gh/calls.log
printf 'example-org/notes-api\n' > .fake-gh/repo

U=https://github.com/example-org/notes-api/issues
cat > .fake-gh/issues.json <<JSON
[{"number": 40, "title": "Spec: tag cleanup", "state": "OPEN", "url": "$U/40",
  "labels": [{"name": "tags-v2"}],
  "subIssues": {"nodes": [{"number": 41, "state": "CLOSED"}, {"number": 42, "state": "OPEN"}, {"number": 43, "state": "OPEN"}, {"number": 44, "state": "OPEN"}, {"number": 45, "state": "OPEN"}], "totalCount": 5},
  "blockedBy": {"nodes": [], "totalCount": 0},
  "body": "## Problem\n\nTags are inconsistent across notes.\n\n## User stories\n\n1. Tags are lowercase and unique per note.\n2. Search notes by tag.\n3. Existing notes get normalized tags.\n"},
 {"number": 41, "title": "Normalize note tags", "state": "CLOSED", "url": "$U/41",
  "labels": [{"name": "tags-v2"}, {"name": "ready-for-agent"}],
  "blockedBy": {"nodes": [], "totalCount": 0},
  "comments": [{"body": "Landed on main. normalizeTags lives in lib/tags.js; reuse it rather than lowercasing inline."}],
  "body": "## Parent\n\n#40\n\n## What to build\n\nnormalizeTags in lib/tags.js: lowercase, trim, dedupe.\n"},
 {"number": 42, "title": "Search notes by tag", "state": "OPEN", "url": "$U/42",
  "labels": [{"name": "tags-v2"}, {"name": "ready-for-agent"}],
  "blockedBy": {"nodes": [{"number": 41, "state": "CLOSED", "title": "Normalize note tags", "url": "$U/41"}], "totalCount": 1},
  "body": "## Parent\n\n#40\n\n## What to build\n\nGET /notes?tag=<tag> returns notes with that tag, matching case-insensitively.\n\n## Acceptance criteria\n\n- [ ] ?tag=Work and ?tag=work return the same notes\n- [ ] An unknown tag returns an empty list\n\n## Blocked by\n\n- #41\n"},
 {"number": 43, "title": "Backfill normalized tags on existing notes", "state": "OPEN", "url": "$U/43",
  "labels": [{"name": "tags-v2"}, {"name": "ready-for-agent"}],
  "blockedBy": {"nodes": [{"number": 41, "state": "CLOSED", "title": "Normalize note tags", "url": "$U/41"}], "totalCount": 1},
  "body": "## Parent\n\n#40\n\n## What to build\n\nA one-off script that rewrites the tags of every existing note in the production notes database with normalizeTags.\n\n## Acceptance criteria\n\n- [ ] Every note's tags are lowercase, trimmed and unique\n- [ ] A rollback file records each note's tags before the change\n\n## Blocked by\n\n- #41\n"},
 {"number": 44, "title": "Tag autocomplete", "state": "OPEN", "url": "$U/44",
  "labels": [{"name": "tags-v2"}, {"name": "ready-for-agent"}],
  "blockedBy": {"nodes": [{"number": 42, "state": "OPEN", "title": "Search notes by tag", "url": "$U/42"}], "totalCount": 1},
  "body": "## Parent\n\n#40\n\n## What to build\n\nSuggest existing tags as the user types, using the tag search endpoint.\n"},
 {"number": 45, "title": "Tag colors", "state": "OPEN", "url": "$U/45",
  "labels": [{"name": "tags-v2"}, {"name": "ready-for-agent"}],
  "blockedBy": {"nodes": [], "totalCount": 0},
  "body": "## Parent\n\n#40\n\n## What to build\n\nEach tag gets a stable color.\n\n## Blocked by\n\n- #43\n"},
 {"number": 46, "title": "Billing export", "state": "OPEN", "url": "$U/46",
  "labels": [{"name": "billing"}, {"name": "ready-for-agent"}],
  "blockedBy": {"nodes": [], "totalCount": 0},
  "body": "## What to build\n\nCSV export of invoices.\n"},
 {"number": 47, "title": "Old tag picker", "state": "CLOSED", "url": "$U/47",
  "labels": [{"name": "tags-v2"}],
  "blockedBy": {"nodes": [], "totalCount": 0},
  "body": "Superseded.\n"}]
JSON
