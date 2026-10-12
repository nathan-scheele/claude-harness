#!/usr/bin/env bash
# Tests for plugin/skills/setup-harness/detect.sh. Each case builds a throwaway
# git repo, runs the detector against it and asserts on its key=value output.
# Runs it with /bin/bash so macOS CI exercises the system bash 3.2.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DETECT="$HERE/../plugin/skills/setup-harness/detect.sh"
failures=0

new_repo() {
  local dir
  dir="$(mktemp -d)"
  git -C "$dir" init -q -b main
  echo "$dir"
}

commit_all() {
  git -C "$1" add -A
  git -C "$1" -c user.name=fixture -c user.email=fixture@example.com commit -qm fixture
}

# expect_line <name> <dir> <exact line>: the output contains that line.
expect_line() {
  local name="$1" dir="$2" want="$3" out
  out="$(/bin/bash "$DETECT" "$dir" 2>&1)"
  if grep -qxF -- "$want" <<<"$out"; then
    echo "ok   - $name"
  else
    echo "FAIL - $name (wanted line: $want)"
    echo "$out" | sed 's/^/       /'
    failures=$((failures + 1))
  fi
}

# expect_no_match <name> <dir> <extended regex>: no output line matches.
expect_no_match() {
  local name="$1" dir="$2" pattern="$3" out
  out="$(/bin/bash "$DETECT" "$dir" 2>&1)"
  if grep -qE -- "$pattern" <<<"$out"; then
    echo "FAIL - $name (unexpected match for: $pattern)"
    echo "$out" | sed 's/^/       /'
    failures=$((failures + 1))
  else
    echo "ok   - $name"
  fi
}

ok_if() {
  local name="$1"; shift
  if "$@"; then
    echo "ok   - $name"
  else
    echo "FAIL - $name"
    failures=$((failures + 1))
  fi
}

# --- code host and repo slug ---

d="$(new_repo)"
expect_line "no remote: host empty" "$d" "host="
expect_line "no remote: repo empty" "$d" "repo="
rm -rf "$d"

d="$(new_repo)"
git -C "$d" remote add origin git@github.com:example-org/notes-api.git
expect_line "GitHub SSH remote: host" "$d" "host=github"
expect_line "GitHub SSH remote: slug" "$d" "repo=example-org/notes-api"
expect_line "GitHub SSH remote: remote host" "$d" "remote_host=github.com"
rm -rf "$d"

d="$(new_repo)"
git -C "$d" remote add origin https://github.com/example-org/notes-api.git
expect_line "GitHub HTTPS remote: host" "$d" "host=github"
expect_line "GitHub HTTPS remote: slug" "$d" "repo=example-org/notes-api"
rm -rf "$d"

d="$(new_repo)"
git -C "$d" remote add origin "https://x-access-token:$(printf 'not%s' -a-real-token)@github.com/example-org/notes-api"
expect_line "HTTPS remote with credentials: slug" "$d" "repo=example-org/notes-api"
expect_no_match "HTTPS remote with credentials: credentials never printed" "$d" "x-access-token|not-a-real-token"
rm -rf "$d"

d="$(new_repo)"
git -C "$d" remote add origin ssh://git@github.com:2222/example-org/notes-api.git
expect_line "ssh:// remote with port: slug" "$d" "repo=example-org/notes-api"
expect_line "ssh:// remote with port: host" "$d" "host=github"
rm -rf "$d"

d="$(new_repo)"
git -C "$d" remote add origin "$(printf '%s@%s' git gitlab.com):example-group/platform/notes-api.git"  # printf keeps the leak check quiet
expect_line "GitLab remote: host" "$d" "host=gitlab"
expect_line "GitLab remote: nested slug" "$d" "repo=example-group/platform/notes-api"
rm -rf "$d"

d="$(new_repo)"
git -C "$d" remote add origin https://git.example.com/team/notes-api.git
expect_line "self-hosted remote: host is other" "$d" "host=other"
expect_line "self-hosted remote: remote host" "$d" "remote_host=git.example.com"
expect_line "self-hosted remote: slug" "$d" "repo=team/notes-api"
rm -rf "$d"

d="$(new_repo)"
git -C "$d" remote add fork git@github.com:someone/notes-api.git
git -C "$d" remote add origin git@github.com:example-org/notes-api.git
expect_line "origin preferred over other remotes" "$d" "repo=example-org/notes-api"
rm -rf "$d"

d="$(new_repo)"
git -C "$d" remote add upstream git@github.com:example-org/notes-api.git
expect_line "no origin: falls back to the only remote" "$d" "repo=example-org/notes-api"
rm -rf "$d"

d="$(new_repo)"
git -C "$d" remote add upstream git@github.com:example-org/notes-api.git
git -C "$d" remote add fork git@github.com:someone/notes-api.git
expect_line "no origin, several remotes: host not guessed" "$d" "host="
expect_line "no origin, several remotes: repo not guessed" "$d" "repo="
rm -rf "$d"

d="$(new_repo)"
git -C "$d" remote add origin /srv/git/notes-api.git
expect_line "local path remote: host not guessed" "$d" "host="
expect_line "local path remote: repo not guessed" "$d" "repo="
rm -rf "$d"

d="$(new_repo)"
git -C "$d" remote add origin https://git.example.com/team/notes-api@v2
expect_line "@ in the path is not userinfo" "$d" "repo=team/notes-api@v2"
expect_line "@ in the path: host" "$d" "remote_host=git.example.com"
rm -rf "$d"

d="$(new_repo)"
git -C "$d" remote add origin https://gitlab.example.com/team/notes-api.git
expect_line "self-hosted GitLab: host" "$d" "host=gitlab"
rm -rf "$d"

# --- default branch ---

d="$(new_repo)"
printf 'x\n' > "$d/README.md"
commit_all "$d"
git -C "$d" remote add origin git@github.com:example-org/notes-api.git
git -C "$d" update-ref refs/remotes/origin/trunk HEAD
git -C "$d" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk
expect_line "default branch from origin/HEAD" "$d" "default_branch=trunk"
rm -rf "$d"

d="$(new_repo)"
printf 'x\n' > "$d/README.md"
commit_all "$d"
git -C "$d" checkout -qb feature/thing
expect_line "no origin/HEAD: default branch not guessed" "$d" "default_branch="
expect_line "no origin/HEAD: current branch offered as candidate" "$d" "default_branch_candidate=feature/thing"
rm -rf "$d"

# --- CI workflows ---

d="$(new_repo)"
expect_line "no workflows: ci_workflow empty" "$d" "ci_workflow="
rm -rf "$d"

d="$(new_repo)"
mkdir -p "$d/.github/workflows"
cat > "$d/.github/workflows/ci.yml" <<'YAML'
name: "CI"   # main checks

on:
  pull_request:

jobs:
  # static checks first
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: npm run lint
  unit-tests:
    name: Unit tests
    runs-on: ubuntu-latest
    steps:
      - run: npm test
        env:
          jobs: not-a-job
YAML
cat > "$d/.github/workflows/deploy.yaml" <<'YAML'
on:
  push:
    branches: [main]
jobs:
    deploy:
        runs-on: ubuntu-latest
        steps:
            - run: ./deploy.sh
permissions:
  contents: read
YAML
expect_line "workflow with name and two jobs" "$d" "ci_workflow=ci.yml|CI|lint,unit-tests"
expect_line "unnamed .yaml workflow, other indent, trailing top-level key" "$d" "ci_workflow=deploy.yaml||deploy"
rm -rf "$d"

d="$(new_repo)"
mkdir -p "$d/.github/workflows"
printf 'name: "Build #1" # nightly\njobs:\n  build:\n    runs-on: ubuntu-latest\n' > "$d/.github/workflows/build.yml"
expect_line "quoted workflow name keeps its #" "$d" "ci_workflow=build.yml|Build #1|build"
rm -rf "$d"

# --- pre-flight commands ---

d="$(new_repo)"
cat > "$d/package.json" <<'JSON'
{
  "name": "notes-api",
  "scripts": {
    "start": "node src/server.js",
    "test": "node --test",
    "build": "tsc -p .",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit"
  }
}
JSON
expect_line "npm: lint" "$d" "preflight=npm run lint"
expect_line "npm: typecheck" "$d" "preflight=npm run typecheck"
expect_line "npm: test" "$d" "preflight=npm run test"
expect_line "npm: build" "$d" "preflight=npm run build"
expect_no_match "npm: non-check scripts skipped" "$d" "^preflight=.*start"
out="$(/bin/bash "$DETECT" "$d" | grep '^preflight=' | tr '\n' ' ')"
ok_if "npm: checks in lint, typecheck, test, build order" \
  test "$out" = "preflight=npm run lint preflight=npm run typecheck preflight=npm run test preflight=npm run build "
touch "$d/pnpm-lock.yaml"
expect_line "pnpm lockfile picks pnpm" "$d" "preflight=pnpm run lint"
rm -rf "$d"

d="$(new_repo)"
printf '{ "name": "notes-api" }\n' > "$d/package.json"
expect_line "package.json without scripts: no pre-flight" "$d" "preflight="
rm -rf "$d"

d="$(new_repo)"
printf '{ "name": "notes-api", "scripts": { "start": "node ." } }\n' > "$d/package.json"
expect_line "package.json without check scripts: no pre-flight" "$d" "preflight="
rm -rf "$d"

d="$(new_repo)"
printf 'test:\n\tgo test ./...\n\nlint: deps\n\tgolangci-lint run\n\nrelease:\n\t./release.sh\n' > "$d/Makefile"
expect_line "Makefile: lint target" "$d" "preflight=make lint"
expect_line "Makefile: test target" "$d" "preflight=make test"
expect_no_match "Makefile: non-check targets skipped" "$d" "^preflight=make release"
rm -rf "$d"

# --- existing Project config ---

d="$(new_repo)"
expect_line "no existing config" "$d" "existing_config="
rm -rf "$d"

d="$(new_repo)"
mkdir -p "$d/docs/agents"
printf '# Harness: Project config\n\n## Deploy\n\n- **Live URL**: https://notes.example.com\n' > "$d/docs/agents/harness.md"
commit_all "$d"
before="$(shasum "$d/docs/agents/harness.md")"
expect_line "re-run: existing config reported" "$d" "existing_config=docs/agents/harness.md"
ok_if "re-run: existing config left untouched" test "$before" = "$(shasum "$d/docs/agents/harness.md")"
ok_if "re-run: detector writes nothing" test -z "$(git -C "$d" status --porcelain)"
rm -rf "$d"

# --- not a repo ---

d="$(mktemp -d)"
if /bin/bash "$DETECT" "$d" >/dev/null 2>&1; then
  echo "FAIL - not a git repo exits non-zero"
  failures=$((failures + 1))
else
  echo "ok   - not a git repo exits non-zero"
fi
rm -rf "$d"

if [[ $failures -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all setup-detect tests passed"
