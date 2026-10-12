#!/usr/bin/env bash
# Tests for plugin/evals/fakes/gh, the stand-in GitHub CLI eval fixtures install.
# Each case builds a throwaway scenario directory, runs the fake against it and
# asserts on its output, exit code and call log. Runs it with /bin/bash so macOS
# CI exercises the system bash 3.2.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FAKE="$HERE/../plugin/evals/fakes/gh"
failures=0

# new_scenario: a scenario dir with one CI run (2001) that is queued, then
# running, then fails in the "Run tests" step of its "test" job.
new_scenario() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/runs/2001" "$dir/prs"
  printf 'example-org/notes-api\n' > "$dir/repo"
  cat > "$dir/runs/2001/run.json" <<'JSON'
{"databaseId": 2001, "workflowName": "CI", "path": ".github/workflows/ci.yml",
 "headBranch": "add-note-tags", "headSha": "1111111111111111111111111111111111111111",
 "event": "push", "displayTitle": "Add tag normalization",
 "url": "https://github.com/example-org/notes-api/actions/runs/2001"}
JSON
  cat > "$dir/runs/2001/timeline.jsonl" <<'JSONL'
{"status": "queued", "conclusion": "", "jobs": []}
{"status": "in_progress", "conclusion": "", "jobs": [{"databaseId": 31, "name": "test", "status": "in_progress", "conclusion": "", "steps": [{"number": 1, "name": "Install", "status": "completed", "conclusion": "success"}, {"number": 2, "name": "Run tests", "status": "in_progress", "conclusion": ""}]}]}
{"status": "completed", "conclusion": "failure", "jobs": [{"databaseId": 31, "name": "test", "status": "completed", "conclusion": "failure", "steps": [{"number": 1, "name": "Install", "status": "completed", "conclusion": "success"}, {"number": 2, "name": "Run tests", "status": "completed", "conclusion": "failure"}]}]}
JSONL
  printf 'test\tRun tests\t2026-01-01T00:00:00Z not ok 3 - normalizeTags drops empty tags\n' > "$dir/runs/2001/log-failed.txt"
  cat > "$dir/prs/7.json" <<'JSON'
{"number": 7, "title": "Add tag normalization", "state": "OPEN", "headRefName": "add-note-tags",
 "url": "https://github.com/example-org/notes-api/pull/7"}
JSON
  echo "$dir"
}

# fake <dir> <args...>: runs the fake against a scenario; sets $out and $code.
fake() {
  local dir="$1"; shift
  out="$(FAKE_GH_DIR="$dir" /bin/bash "$FAKE" "$@" 2>&1)"
  code=$?
}

ok_if() {
  local name="$1"; shift
  if "$@"; then
    echo "ok   - $name"
  else
    echo "FAIL - $name"
    echo "$out" | sed 's/^/       /'
    failures=$((failures + 1))
  fi
}

has() { grep -qF -- "$1" <<<"$out"; }
lacks() { ! grep -qF -- "$1" <<<"$out"; }
logged() { grep -qxF -- "$2" "$1/calls.log"; }

# --- call log ---

d="$(new_scenario)"
fake "$d" run view 2001 --json status
ok_if "every call is logged" logged "$d" "gh run view 2001 --json status"
fake "$d" frobnicate --now
ok_if "unknown subcommand exits non-zero" test "$code" -ne 0
ok_if "unknown subcommand names what is supported" has "supported"
ok_if "unknown subcommand is still logged" logged "$d" "gh frobnicate --now"
fake "$d" run view 9999 --json status
ok_if "unknown run exits non-zero" test "$code" -ne 0
ok_if "unknown run is still logged" logged "$d" "gh run view 9999 --json status"
rm -rf "$d"

# --- state advances per status read ---

d="$(new_scenario)"
fake "$d" run view 2001 --json status,conclusion
ok_if "first read: queued" test "$out" = '{"status":"queued","conclusion":""}'
fake "$d" run view 2001 --json status
ok_if "second read: in_progress" test "$out" = '{"status":"in_progress"}'
fake "$d" run view 2001 --json status,conclusion --jq '.status + " " + .conclusion'
ok_if "third read: completed failure, --jq applied" test "$out" = "completed failure"
fake "$d" run view 2001 --json status
ok_if "reads past the timeline stay on the last state" test "$out" = '{"status":"completed"}'
rm -rf "$d"

d="$(new_scenario)"
fake "$d" run list --json databaseId,status
ok_if "run list is a status read: first state" test "$out" = '[{"databaseId":2001,"status":"queued"}]'
fake "$d" run view 2001 --json status
ok_if "run view after run list sees the next state" test "$out" = '{"status":"in_progress"}'
fake "$d" run view 2001 --log-failed
ok_if "log reads do not advance the run" test "$code" -ne 0
fake "$d" run view 2001 --json status
ok_if "state after a log read is the next tick" test "$out" = '{"status":"completed"}'
rm -rf "$d"

# --- run list filters ---

d="$(new_scenario)"
fake "$d" run list --workflow ci.yml --branch add-note-tags --json databaseId --jq '.[].databaseId'
ok_if "run list: workflow file and branch match" test "$out" = "2001"
fake "$d" run list --workflow CI --json databaseId --jq 'length'
ok_if "run list: workflow name matches" test "$out" = "1"
fake "$d" run list --workflow deploy.yml --json databaseId --jq 'length'
ok_if "run list: other workflow filtered out" test "$out" = "0"
fake "$d" run list -b main --json databaseId --jq 'length'
ok_if "run list: other branch filtered out" test "$out" = "0"
fake "$d" run list
ok_if "run list: plain text names the run" has "2001"
rm -rf "$d"

# --- failure run: failing step and logs ---

d="$(new_scenario)"
fake "$d" run view 2001 --log-failed
ok_if "--log-failed while running: exits non-zero" test "$code" -ne 0
ok_if "--log-failed while running: says it is still running" has "in progress"
fake "$d" run watch 2001 --exit-status
ok_if "run watch jumps to the final state" has "failure"
ok_if "run watch --exit-status fails for a failed run" test "$code" -ne 0
fake "$d" run view 2001 --json jobs --jq '.jobs[] | select(.conclusion == "failure") | .steps[] | select(.conclusion == "failure") | .name'
ok_if "failed job's failing step is in --json jobs" test "$out" = "Run tests"
fake "$d" run view 2001 --log-failed
ok_if "--log-failed when done: canned failing step log" has "not ok 3 - normalizeTags drops empty tags"
ok_if "--log-failed when done: exits zero" test "$code" -eq 0
fake "$d" run view 2001
ok_if "plain run view: failing step named" has "Run tests"
ok_if "plain run view: deep link" has "https://github.com/example-org/notes-api/actions/runs/2001"
fake "$d" run view 2001 --log
ok_if "--log with no canned full log: exits non-zero" test "$code" -ne 0
rm -rf "$d"

# --- pull requests ---

d="$(new_scenario)"
fake "$d" pr view 7 --json number,headRefName
ok_if "pr view: canned fields" test "$out" = '{"number":7,"headRefName":"add-note-tags"}'
fake "$d" pr checks 7
ok_if "pr checks while queued: exit 8 (pending)" test "$code" -eq 8
fake "$d" pr checks 7
ok_if "pr checks: job listed" has "test"
fake "$d" pr checks 7
ok_if "pr checks after failure: exit 1" test "$code" -eq 1
ok_if "pr checks after failure: fail bucket" has "fail"
fake "$d" pr view 99 --json number
ok_if "pr view of an unknown PR exits non-zero" test "$code" -ne 0
rm -rf "$d"

# --- issues ---

d="$(new_scenario)"
fake "$d" issue list --search "normalizeTags" --json number,title
ok_if "issue list with no canned issues: empty array" test "$out" = "[]"
fake "$d" issue create --title "Tests fail" --body "Run tests step fails"
ok_if "issue create prints the new issue URL" has "https://github.com/example-org/notes-api/issues/"
ok_if "issue create is logged" logged "$d" "gh issue create --title Tests fail --body Run tests step fails"
fake "$d" issue list --json number,title --jq '.[].title'
ok_if "created issue shows in issue list" test "$out" = "Tests fail"
fake "$d" issue create --body "no title"
ok_if "issue create without a title exits non-zero" test "$code" -ne 0
rm -rf "$d"

# --- job-scoped logs ---

d="$(new_scenario)"
fake "$d" run watch 2001
fake "$d" run view --job 31 --log-failed
ok_if "--job --log-failed falls back to the run's failed log" has "not ok 3"
fake "$d" run view --job 99 --log
ok_if "--job for an unknown job exits non-zero" test "$code" -ne 0
mkdir -p "$d/runs/2001/jobs"
printf 'full log of job 31\n' > "$d/runs/2001/jobs/31.log"
fake "$d" run view --job 31 --log
ok_if "--job --log reads the job's canned log" test "$out" = "full log of job 31"
rm -rf "$d"

# --- misc ---

d="$(new_scenario)"
fake "$d" auth status
ok_if "auth status succeeds" test "$code" -eq 0
fake "$d" run view 2001 --json 'status;rm'
ok_if "--json rejects anything but field names" test "$code" -ne 0
fake "$d" run view 2001 --template '{{.status}}'
ok_if "unsupported output flag exits non-zero" test "$code" -ne 0
fake "$d" run list --bogus
ok_if "unknown flag names the command's flags" has "--workflow"
fake "$d" run list -L1 --json databaseId --jq 'length'
ok_if "short flag with its value attached" test "$out" = "1"
rm -rf "$d"

# --- malformed scenarios fail clearly ---

d="$(new_scenario)"
mkdir -p "$d/runs/notes"
fake "$d" run list --json databaseId --jq 'length'
ok_if "a directory under runs/ without run.json is not a run" test "$out" = "1"
: > "$d/runs/2001/timeline.jsonl"
fake "$d" run view 2001 --json status
ok_if "empty timeline: exits non-zero" test "$code" -ne 0
ok_if "empty timeline: says so" has "timeline"
rm -rf "$d"

d="$(new_scenario)"
printf '{"number": 8, "title": "Docs", "state": "OPEN", "headRefName": "docs-only", "url": "https://github.com/example-org/notes-api/pull/8"}\n' > "$d/prs/8.json"
fake "$d" pr checks 8
ok_if "pr checks with no runs on the branch: exits non-zero" test "$code" -ne 0
ok_if "pr checks with no runs on the branch: says no checks" has "no checks reported"
rm -rf "$d"

if [[ $failures -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all fake-gh tests passed"
