#!/usr/bin/env bash
# Builds the fixture repo in the current directory: the same notes web app as
# live-verifier-dev-table, but setup-harness never ran, so there is no Project
# config (docs/agents/harness.md) naming the dev target or the reset command.
set -euo pipefail

mkdir -p src scripts fixtures
cat > package.json <<'JSON'
{
  "name": "notes-web",
  "version": "1.4.0",
  "private": true,
  "scripts": { "start": "node src/server.js", "test": "node --test" }
}
JSON
cat > src/server.js <<'JS'
// Serves /notes and /notes?tag=<tag> from the database.
JS
cat > fixtures/notes.json <<'JSON'
[
  { "title": "Groceries", "tags": ["home"] },
  { "title": "Standup notes", "tags": ["work"] },
  { "title": "Quarterly plan", "tags": ["work", "planning"] }
]
JSON
cat > scripts/reset-fixtures.sh <<'SH'
#!/usr/bin/env bash
# Puts the dev database back to fixtures/notes.json.
set -euo pipefail
mkdir -p .fixtures
echo "reset" >> .fixtures/reset.log
SH
chmod +x scripts/reset-fixtures.sh
