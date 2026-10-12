#!/usr/bin/env bash
# Builds the fixture repo in the current directory: a tiny Node service whose
# `origin` is a local bare repo (kept inside .git so it never shows as
# untracked), checked out on a feature branch that was pushed and then
# squash-merged into origin/main. The branch's commit SHA is not on main but
# its content is, so closing out should be "safe to clear".
set -euo pipefail

git init -q -b main
git config user.name fixture
git config user.email fixture@example.com

mkdir -p src docs
cat > package.json <<'JSON'
{
  "name": "notes-api",
  "version": "0.9.0",
  "private": true,
  "scripts": { "test": "node --test", "start": "node src/server.js" }
}
JSON
cat > src/server.js <<'JS'
const http = require("node:http");
const notes = [];
http
  .createServer((req, res) => {
    if (req.method === "GET" && req.url === "/notes") {
      res.end(JSON.stringify(notes));
      return;
    }
    res.statusCode = 404;
    res.end();
  })
  .listen(process.env.PORT || 3000);
JS
cat > README.md <<'MD'
# notes-api

A small notes service. See docs/roadmap.md for what's next.
MD
cat > docs/roadmap.md <<'MD'
# Roadmap

- [ ] Tag normalization for notes
- [ ] Pagination for GET /notes (next up)
MD
git add -A
git commit -qm "notes-api 0.9.0"

git init -q --bare -b main .git/fixture-origin.git
git remote add origin "$PWD/.git/fixture-origin.git"
git push -q -u origin main
git remote set-head origin main >/dev/null

git switch -q -c add-note-tags
cat > src/tags.js <<'JS'
// Tags are lowercase, trimmed and unique per note.
function normalizeTags(tags) {
  return [...new Set(tags.map((t) => t.trim().toLowerCase()).filter(Boolean))];
}
module.exports = { normalizeTags };
JS
sed -i.bak 's/- \[ \] Tag normalization/- [x] Tag normalization/' docs/roadmap.md
rm docs/roadmap.md.bak
git add -A
git commit -qm "Add tag normalization for notes"
git push -q -u origin add-note-tags

# Squash-merge the branch into main on the remote, as a code host would.
git switch -q main
git merge -q --squash add-note-tags >/dev/null
git commit -qm "Add tag normalization for notes (#12)"
git push -q origin main
git switch -q add-note-tags
