#!/usr/bin/env bash
# Detects the Project config values a repo can answer for itself and prints
# them as key=value lines. Read-only: it never writes to the repo.
#
# Usage: detect.sh [repo-dir]   (default: current directory)
#
# Every key is printed at least once; an empty value means "not detected" and
# must be asked for, never guessed. List keys (ci_workflow, preflight) repeat
# once per item.
#
#   host=github|gitlab|bitbucket|other   code host, from origin or the only remote
#   remote_host=<hostname>               the remote's hostname (never credentials)
#   repo=<owner>/<name>                  repo slug (may have subgroups)
#   default_branch=<branch>              from <remote>/HEAD only
#   default_branch_candidate=<branch>    the checked-out branch, to offer when
#                                        default_branch is empty
#   ci_workflow=<file>|<name>|<job,job>  one line per GitHub Actions workflow
#   preflight=<command>                  check commands found in package.json
#                                        scripts or Makefile targets
#   existing_config=<path>               docs/agents/harness.md if present
#
# Bash 3.2 compatible (macOS default shell).
set -euo pipefail

dir="${1:-.}"
if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "detect.sh: $dir is not a git repository" >&2
  exit 1
fi
cd "$(git -C "$dir" rev-parse --show-toplevel)"

# Script and target names treated as pre-flight checks, in run order.
CHECKS="lint typecheck check test build"
NL='
'

# --- code host and repo slug ---

# origin, or the only remote; several remotes without an origin is ambiguous.
remote=""
if git remote get-url origin >/dev/null 2>&1; then
  remote=origin
elif [ "$(git remote | wc -l | tr -d ' ')" = 1 ]; then
  remote="$(git remote)"
fi

host="" remote_host="" repo=""
if [ -n "$remote" ]; then
  url="$(git remote get-url "$remote")"
  path=""
  case "$url" in
    file://*) ;;                                # local: nothing to detect
    *://*)
      rest="${url#*://}"
      authority="${rest%%/*}"
      authority="${authority##*@}"              # drop user[:password]@
      remote_host="${authority%%:*}"            # drop :port
      case "$rest" in */*) path="${rest#*/}" ;; esac
      ;;
    *@*:*)                                      # scp-like: user@host:path
      rest="${url#*@}"
      remote_host="${rest%%:*}"
      path="${rest#*:}"
      ;;
  esac
  path="${path%/}"
  repo="${path%.git}"
  case "$remote_host" in
    "") ;;
    github.com) host=github ;;
    gitlab.com | gitlab.*) host=gitlab ;;
    bitbucket.org) host=bitbucket ;;
    *) host=other ;;
  esac
fi
echo "host=$host"
echo "remote_host=$remote_host"
echo "repo=$repo"

# --- default branch ---

default_branch=""
if [ -n "$remote" ]; then
  ref="$(git symbolic-ref -q --short "refs/remotes/$remote/HEAD" 2>/dev/null || true)"
  default_branch="${ref#"$remote"/}"
fi
echo "default_branch=$default_branch"
echo "default_branch_candidate=$(git symbolic-ref -q --short HEAD 2>/dev/null || true)"

# --- CI workflows (GitHub Actions) ---

workflow_name() {
  awk '/^name:/ {
    sub(/^name:[[:space:]]*/, "")
    q = substr($0, 1, 1)
    if (q == "\"" || q == "\047") {
      $0 = substr($0, 2)
      sub(q ".*$", "")                 # up to the closing quote
    } else {
      sub(/[[:space:]]+#.*$/, "")      # unquoted: drop a trailing comment
    }
    print
    exit
  }' "$1"
}

# Job ids: the keys one indent level below the top-level `jobs:` key.
workflow_jobs() {
  awk '
    /^jobs:[[:space:]]*(#.*)?$/ { injobs = 1; next }
    injobs && /^[^[:space:]#]/ { injobs = 0 }
    injobs {
      if ($0 ~ /^[[:space:]]*(#.*)?$/) next
      match($0, /^[[:space:]]*/)
      if (!indent) indent = RLENGTH
      if (RLENGTH != indent) next
      id = substr($0, indent + 1)
      sub(/:.*/, "", id)
      gsub(/["\047]/, "", id)
      jobs = jobs (jobs ? "," : "") id
    }
    END { print jobs }
  ' "$1"
}

found_workflow=""
for f in .github/workflows/*.yml .github/workflows/*.yaml; do
  [ -f "$f" ] || continue
  found_workflow=1
  echo "ci_workflow=$(basename "$f")|$(workflow_name "$f")|$(workflow_jobs "$f")"
done
[ -n "$found_workflow" ] || echo "ci_workflow="

# --- pre-flight commands ---

package_scripts() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.scripts // {} | keys[]' package.json 2>/dev/null || true
  elif command -v node >/dev/null 2>&1; then
    node -e 'const p = require("./package.json"); for (const k of Object.keys(p.scripts || {})) console.log(k)' 2>/dev/null || true
  fi
}

found_preflight=""
if [ -f package.json ]; then
  runner=npm
  if [ -f pnpm-lock.yaml ]; then runner=pnpm
  elif [ -f yarn.lock ]; then runner=yarn
  elif [ -f bun.lockb ] || [ -f bun.lock ]; then runner=bun
  fi
  scripts="$(package_scripts)"
  for check in $CHECKS; do
    case "$NL$scripts$NL" in
      *"$NL$check$NL"*)
        echo "preflight=$runner run $check"
        found_preflight=1
        ;;
    esac
  done
fi
if [ -f Makefile ]; then
  for check in $CHECKS; do
    if grep -qE "^$check[[:space:]]*:([^=]|$)" Makefile; then
      echo "preflight=make $check"
      found_preflight=1
    fi
  done
fi
[ -n "$found_preflight" ] || echo "preflight="

# --- existing Project config ---

if [ -f docs/agents/harness.md ]; then
  echo "existing_config=docs/agents/harness.md"
else
  echo "existing_config="
fi
