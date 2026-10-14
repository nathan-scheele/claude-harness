#!/usr/bin/env bash
# Tests for scripts/release-check.sh. Each case builds a throwaway repo layout
# (plugin manifest + CHANGELOG.md), runs the check against it and asserts on
# the exit code.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/release-check.sh"
failures=0

CURRENT='# Changelog\n\n## 0.1.0 - 2026-10-13\n\n- Things.\n'

# new_repo <version> <changelog text>
new_repo() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/plugin/.claude-plugin"
  printf '{\n  "name": "harness",\n  "version": "%s"\n}\n' "$1" > "$dir/plugin/.claude-plugin/plugin.json"
  printf '%b' "$2" > "$dir/CHANGELOG.md"
  echo "$dir"
}

# expect <pass|fail> <name> <dir> [tag]
expect() {
  local want="$1" name="$2" dir="$3"
  shift 3
  local out code
  out="$("$CHECK" "$dir" "$@" 2>&1)"
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

d="$(new_repo 0.1.0 "$CURRENT")"
expect pass "version with a changelog entry passes" "$d"

d="$(new_repo 0.1.0 '# Changelog\n\n## 0.0.1\n\n- Skeleton.\n')"
expect fail "version missing from changelog fails" "$d"

d="$(new_repo 0.1.0 "$CURRENT")"
expect pass "matching tag passes" "$d" v0.1.0

d="$(new_repo 0.1.0 "$CURRENT")"
expect fail "tag for another version fails" "$d" v0.2.0

d="$(new_repo 0.1.0 "$CURRENT")"
expect fail "tag without the v prefix fails" "$d" 0.1.0

d="$(new_repo 0.1.0 '# Changelog\n\n## 0.1.01\n\n- Typo.\n')"
expect fail "a longer version that starts the same does not count" "$d"

d="$(new_repo 0.2.0 '# Changelog\n\n## 0.2.0\n\n- Newer.\n\n## 0.1.0\n\n- Older.\n')"
expect pass "entry need not be dated" "$d"

d="$(new_repo 0.1.0 '# Changelog\n\n## 0.2.0\n\n- Newer.\n\n## 0.1.0\n\n- Older.\n')"
expect fail "version must be the newest entry" "$d"

d="$(new_repo 0.1.0 '# Changelog\n\n## 0.1.0\n')"
rm "$d/CHANGELOG.md"
expect fail "missing changelog fails" "$d"

d="$(new_repo '' '# Changelog\n\n## 0.1.0\n')"
expect fail "missing version fails" "$d"

d="$(new_repo 0.1.0 "$CURRENT")"
printf '{\n  "name": "harness",\n  "mcpServers": {\n    "x": { "version": "9.9.9" }\n  },\n  "version": "0.1.0"\n}\n' > "$d/plugin/.claude-plugin/plugin.json"
expect pass "a nested version key is ignored" "$d"

if [[ $failures -gt 0 ]]; then
  echo "$failures release-check test(s) failed"
  exit 1
fi
echo "all release-check tests passed"
