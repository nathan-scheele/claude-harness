#!/usr/bin/env bash
# Fail if any tracked or untracked-but-not-ignored file in a repo contains a
# project-specific identifier: real email addresses, absolute home paths,
# store domains or platform resource IDs.
#
# Usage: scripts/leak-check.sh [repo-dir]
#
# Operator-private identifiers (a work domain, a store name) must not appear in
# this public file, so pass them at runtime instead: LEAK_PATTERNS holds extra
# extended regexes, one per line (CI reads it from a repository secret).
set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

# label<TAB>extended regex
PATTERNS=$(cat <<'EOF'
email	[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}
home path	/(Users|home)/[A-Za-z0-9._-]+/
store domain	[A-Za-z0-9-]+\.myshopify\.com
store admin URL	admin\.shopify\.com/store/[A-Za-z0-9-]+
resource ID	gid://[A-Za-z]+/[A-Za-z]+/[0-9]+
resource ID	\b(app|tbl|fld|viw|rec|sel|wsp)[A-Za-z0-9]{14}\b
EOF
)

# Emails that are public by design.
EMAIL_ALLOW='@(example\.(com|org|net)|anthropic\.com|users\.noreply\.github\.com)$|^git@github\.com$'

if [[ -n "${LEAK_PATTERNS:-}" ]]; then
  while IFS= read -r p; do
    [[ -n "$p" ]] && PATTERNS+=$'\n'"private pattern"$'\t'"$p"
  done <<< "$LEAK_PATTERNS"
fi

files=()
while IFS= read -r -d '' f; do
  [[ -f "$f" ]] && files+=("$f")
done < <(git ls-files -z --cached --others --exclude-standard)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "leak-check: no files to scan"
  exit 0
fi

found=0
while IFS=$'\t' read -r label regex; do
  # grep exits 1 for no match and 2+ for a bad regex; a bad regex must not pass as clean.
  status=0
  hits="$(grep -nIE -- "$regex" "${files[@]}" /dev/null)" || status=$?
  if [[ $status -ge 2 ]]; then
    echo "leak-check: invalid $label regex; fix it so the check can run"
    exit 2
  fi
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    if [[ "$label" == email ]]; then
      match="$(grep -oE "$regex" <<< "${hit#*:*:}" | grep -vE "$EMAIL_ALLOW" || true)"
      [[ -z "$match" ]] && continue
    fi
    if [[ "$label" == "private pattern" ]]; then
      # Don't echo the private pattern's match into public CI logs.
      echo "leak-check: $label: ${hit%%:*}"
    else
      echo "leak-check: $label: $hit"
    fi
    found=1
  done <<< "$hits"
done <<< "$PATTERNS"

if [[ $found -ne 0 ]]; then
  echo "leak-check: project-specific identifiers found; replace them with placeholders"
  exit 1
fi
echo "leak-check: clean (${#files[@]} files)"
