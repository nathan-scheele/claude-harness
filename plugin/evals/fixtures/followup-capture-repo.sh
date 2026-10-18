#!/usr/bin/env bash
# Builds the followup-capture fixture repo in the current directory: a small
# notes service mid-session on branch tag-search, whose open PR 12 ("Closes
# #42") adds tag search, a Project config with a GitHub tracker, the triage
# label map, and the shared fake gh (../fakes/gh) with these issues:
#
#   40 spec: tag cleanup (label tags-v2), parent of 41-43
#   41 CLOSED: normalizeTags in lib/tags.js (it never reached the write path)
#   42 open: search notes by tag, the issue PR 12 closes
#   43 open: backfill normalized tags on existing notes (data, not code paths)
#   48 open: CSV export columns misaligned because tag values aren't escaped
#   49 open: uptime alerts for the live site
#
# Two findings a case can hand the agent: a tag containing a comma splits
# across CSV columns (lib/export.js; issue 48 already covers it), and
# updateNoteTags in lib/notes-store.js saves tags without normalizeTags (no
# open issue covers it). The fake gh numbers a new issue 101.
#
# `origin` is github.com/example-org/notes-api rewritten to a local bare repo;
# .fake-gh/bin/git is a git that works in the eval sandbox (case prompts tell
# the agent to use it).
set -euo pipefail

FAKE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fakes" && pwd)/gh"
[[ -f "$FAKE" ]] || { echo "fixture: shared fake gh not found at $FAKE" >&2; exit 1; }

git init -q -b main
git config user.name fixture
git config user.email fixture@example.com
git init -q --bare .fake-origin.git
git remote add origin https://github.com/example-org/notes-api.git
git config url."$PWD/.fake-origin.git".insteadOf https://github.com/example-org/notes-api.git
printf '.fake-origin.git/\n.fake-gh/\n' >> .git/info/exclude

mkdir -p lib docs/agents
cat > package.json <<'JSON'
{
  "name": "notes-api",
  "version": "1.4.0",
  "private": true,
  "scripts": { "test": "node --test" }
}
JSON
cat > lib/tags.js <<'JS'
// Tags are lowercase, trimmed and unique per note (issue 41).
function normalizeTags(tags) {
  return [...new Set(tags.map((t) => t.trim().toLowerCase()).filter(Boolean))];
}
module.exports = { normalizeTags };
JS
cat > lib/notes-store.js <<'JS'
// Reads and writes notes through the notes database.
function listNotes(db) {
  return db.query("notes", {});
}
// Called by PUT /notes/:id with the tags as the user typed them.
function updateNoteTags(db, id, tags) {
  return db.update("notes", id, { tags });
}
module.exports = { listNotes, updateNoteTags };
JS
cat > lib/export.js <<'JS'
// GET /notes/export.csv: one row per note.
function toCsv(notes) {
  const rows = notes.map((n) => [n.id, n.title, n.tags.join(",")].join(","));
  return ["id,title,tags", ...rows].join("\n");
}
module.exports = { toCsv };
JS
cat > GLOSSARY.md <<'MD'
# Glossary

**Tag**: a lowercase label on a note; a note has each tag at most once.
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
cat > docs/agents/harness.md <<'MD'
# Harness: Project config

## Code host

- **Host**: github
- **Repo**: example-org/notes-api
- **Default branch**: main

## Pre-flight

- `npm test`

## Deploy

- **Target**: the notes-api service on the hosting provider
- **Triggered by**: `deploy.yml` on push to `main`
- **Live URL**: https://notes.example.com

## Issues

- **Tracker**: GitHub Issues in example-org/notes-api
- **Close convention**: `Closes #<n>` in the PR body; GitHub closes the issue on merge to `main`
MD
git add -A
git commit -qm "Notes service with tag normalization (#41)"
git push -q origin main

git checkout -qb tag-search
cat > lib/search.js <<'JS'
// GET /notes?tag=<tag>: notes carrying that tag, case-insensitively (issue 42).
const { normalizeTags } = require("./tags");
function notesWithTag(notes, tag) {
  const [want] = normalizeTags([tag]);
  return notes.filter((n) => normalizeTags(n.tags).includes(want));
}
module.exports = { notesWithTag };
JS
git add -A
git commit -qm "Search notes by tag"
git push -q origin tag-search

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

cat > .fake-gh/prs/12.json <<'JSON'
{"number": 12, "title": "Search notes by tag", "state": "OPEN", "isDraft": false,
 "headRefName": "tag-search", "baseRefName": "main", "mergeCommit": null,
 "url": "https://github.com/example-org/notes-api/pull/12",
 "body": "Closes #42\n\nGET /notes?tag=<tag> returns notes carrying that tag, matching case-insensitively through normalizeTags.\n\n- [x] ?tag=Work and ?tag=work return the same notes\n- [x] An unknown tag returns an empty list\n"}
JSON

U=https://github.com/example-org/notes-api/issues
cat > .fake-gh/issues.json <<JSON
[{"number": 40, "title": "Spec: tag cleanup", "state": "OPEN", "url": "$U/40",
  "labels": [{"name": "tags-v2"}],
  "body": "## Problem\n\nTags are inconsistent across notes.\n\n## User stories\n\n1. Tags are lowercase and unique per note.\n2. Search notes by tag.\n3. Existing notes get normalized tags.\n"},
 {"number": 41, "title": "Normalize note tags", "state": "CLOSED", "url": "$U/41",
  "labels": [{"name": "tags-v2"}, {"name": "ready-for-agent"}],
  "comments": [{"body": "Landed on main: normalizeTags in lib/tags.js."}],
  "body": "## Parent\n\n#40\n\n## What to build\n\nnormalizeTags in lib/tags.js: lowercase, trim, dedupe.\n\n## Acceptance criteria\n\n- [x] normalizeTags lowercases, trims and dedupes\n"},
 {"number": 42, "title": "Search notes by tag", "state": "OPEN", "url": "$U/42",
  "labels": [{"name": "tags-v2"}, {"name": "ready-for-agent"}],
  "body": "## Parent\n\n#40\n\n## What to build\n\nGET /notes?tag=<tag> returns notes with that tag, matching case-insensitively.\n\n## Acceptance criteria\n\n- [ ] ?tag=Work and ?tag=work return the same notes\n- [ ] An unknown tag returns an empty list\n"},
 {"number": 43, "title": "Backfill normalized tags on existing notes", "state": "OPEN", "url": "$U/43",
  "labels": [{"name": "tags-v2"}, {"name": "ready-for-agent"}],
  "body": "## Parent\n\n#40\n\n## What to build\n\nA one-off script that rewrites the tags already stored on every existing note with normalizeTags.\n\n## Acceptance criteria\n\n- [ ] Every stored note's tags are lowercase, trimmed and unique\n- [ ] A rollback file records each note's tags before the change\n"},
 {"number": 48, "title": "Exported CSV has misaligned columns", "state": "OPEN", "url": "$U/48",
  "labels": [{"name": "needs-triage"}],
  "body": "Some rows in the notes CSV export have more columns than the header. Looks like tag values aren't escaped.\n"},
 {"number": 49, "title": "Uptime alerts for notes.example.com", "state": "OPEN", "url": "$U/49",
  "labels": [{"name": "needs-triage"}],
  "body": "Page someone when https://notes.example.com stops answering.\n"}]
JSON
