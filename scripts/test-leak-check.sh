#!/usr/bin/env bash
# Tests for scripts/leak-check.sh. Each case builds a throwaway git repo,
# runs the leak check against it and asserts on the exit code.
# Leaky strings are assembled with printf so this file never trips the check itself.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/leak-check.sh"
failures=0

new_repo() {
  local dir
  dir="$(mktemp -d)"
  git -C "$dir" init -q
  echo "$dir"
}

expect() {
  local want="$1" name="$2" dir="$3"
  local out code
  out="$("$CHECK" "$dir" 2>&1)"
  code=$?
  if [[ "$want" == pass && $code -eq 0 ]] || [[ "$want" == fail && $code -ne 0 ]]; then
    echo "ok   - $name"
  else
    echo "FAIL - $name (exit $code)"
    echo "$out" | sed 's/^/       /'
    failures=$((failures + 1))
  fi
  rm -rf "$dir"
}

d="$(new_repo)"
printf '# Hello\nSee https://example.com and contact someone@example.com.\nPaths like ~/.claude/skills are fine.\n' > "$d/README.md"
expect pass "clean repo passes" "$d"

d="$(new_repo)"
printf 'Ping %s@%s about it.\n' ops acme-store.com > "$d/notes.md"
expect fail "real email address fails" "$d"

d="$(new_repo)"
printf 'Co-Authored-By: Claude <%s@%s>\n' noreply anthropic.com > "$d/notes.md"
expect pass "allowlisted noreply email passes" "$d"

d="$(new_repo)"
printf 'Logs are in /%s/%s/code/app.\n' Users alice > "$d/notes.md"
expect fail "macOS home path fails" "$d"

d="$(new_repo)"
printf 'Logs are in /%s/%s/code/app.\n' home bob > "$d/notes.md"
expect fail "Linux home path fails" "$d"

d="$(new_repo)"
printf 'Put it in /Users/<you>/code or $HOME/code.\n' > "$d/notes.md"
expect pass "placeholder home path passes" "$d"

d="$(new_repo)"
printf 'Open https://%s.%s/admin\n' acme-store myshopify.com > "$d/notes.md"
expect fail "store domain fails" "$d"

d="$(new_repo)"
printf 'Product %s://shopify/Product/%s\n' gid 8123456789 > "$d/notes.md"
expect fail "platform resource ID fails" "$d"

d="$(new_repo)"
printf 'Base %s%s table %s%s\n' app AbCdEfGhIjKlMn tbl AbCdEfGhIjKlMn > "$d/notes.md"
expect fail "Airtable-style resource IDs fail" "$d"

d="$(new_repo)"
printf 'Deploys to %s.%s\n' shop acme-store.com > "$d/notes.md"
LEAK_PATTERNS="$(printf '%s[.]com' acme-store)" expect fail "extra private pattern from LEAK_PATTERNS fails" "$d"

d="$(new_repo)"
printf 'Deploys to %s.%s\n' shop acme-store.com > "$d/notes.md"
expect pass "same text passes without the private pattern" "$d"

d="$(new_repo)"
printf 'Ping %s@%s\n' ops acme-store.com > "$d/ignored.log"
printf '*.log\n' > "$d/.gitignore"
expect pass "gitignored files are not scanned" "$d"

d="$(new_repo)"
printf 'Clean text.\n' > "$d/notes.md"
LEAK_PATTERNS='broken(' expect fail "malformed LEAK_PATTERNS regex fails instead of passing" "$d"

d="$(new_repo)"
printf 'Clone %s@%s:owner/repo.git\n' git github.com > "$d/notes.md"
expect pass "git SSH remote is not an email" "$d"

d="$(new_repo)"
printf 'Editor: https://admin.example.com/%s/%s/editor\n' themes 141234567890 > "$d/notes.md"
expect fail "theme ID in a themes/ path fails" "$d"

d="$(new_repo)"
printf 'Preview with ?preview_theme_%s=%s\n' id 141234567890 > "$d/notes.md"
expect fail "theme ID in a theme_id parameter fails" "$d"

d="$(new_repo)"
printf 'Read the theme ID from Project config; edit themes/<id>/editor.\n' > "$d/notes.md"
expect pass "theme ID placeholder passes" "$d"

d="$(new_repo)"
printf 'Helpdesk at https://%s.%s\n' acme gorgias.com > "$d/notes.md"
expect fail "helpdesk account subdomain fails" "$d"

d="$(new_repo)"
printf 'Workspace https://%s.%s/archives\n' acme-team slack.com > "$d/notes.md"
expect fail "chat workspace subdomain fails" "$d"

d="$(new_repo)"
printf 'Create an app at https://%s.%s/apps\n' api slack.com > "$d/notes.md"
expect pass "vendor public host passes" "$d"

d="$(new_repo)"
printf 'Post to channel %s%s as user %s%s\n' C0 7ABCDE123 U0 5FGHIJ456 > "$d/notes.md"
expect fail "chat channel and user IDs fail" "$d"

if [[ $failures -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all leak-check tests passed"
