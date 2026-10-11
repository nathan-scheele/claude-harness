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

if [[ $failures -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all leak-check tests passed"
