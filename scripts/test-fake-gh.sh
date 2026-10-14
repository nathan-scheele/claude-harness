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

# --- opening a PR ---

d="$(new_scenario)"
fake "$d" pr create --title "Add tag normalization" --body "Closes #11" --base main --head tidy-tags
ok_if "pr create prints the new PR URL" has "https://github.com/example-org/notes-api/pull/"
ok_if "pr create is logged" logged "$d" "gh pr create --title Add tag normalization --body Closes #11 --base main --head tidy-tags"
n="$(basename "$out")"
fake "$d" pr view "$n" --json state,headRefName,baseRefName,body
ok_if "created PR is open with its branch and body" test "$out" = '{"state":"OPEN","headRefName":"tidy-tags","baseRefName":"main","body":"Closes #11"}'
fake "$d" pr view "$n" --json mergeable,mergeStateStatus
ok_if "created PR is mergeable" test "$out" = '{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN"}'
fake "$d" pr list --head tidy-tags --json number --jq '.[].number'
ok_if "pr list --head finds the created PR" test "$out" = "$n"
fake "$d" pr list --head other-branch --json number --jq 'length'
ok_if "pr list --head filters other branches" test "$out" = "0"
fake "$d" pr create --title "Again" --body "x" --head tidy-tags
ok_if "a second PR for the same branch exits non-zero" test "$code" -ne 0
ok_if "a second PR for the same branch names the first" has "already exists"
rm -rf "$d"

d="$(new_scenario)"
printf 'Fixes #11\n\nTag chips are lowercase.\n' > "$d/body.md"
fake "$d" pr create --title "Tags" --body-file "$d/body.md" --head tidy-tags
n="$(basename "$out")"
fake "$d" pr view "$n" --json body --jq .body
ok_if "pr create --body-file stores the file's text" has "Fixes #11"
fake "$d" pr create --body "no title" --head other
ok_if "pr create without a title exits non-zero" test "$code" -ne 0
fake "$d" pr create --title "No body" --head other
ok_if "pr create without a body exits non-zero" test "$code" -ne 0
fake "$d" pr edit "$n" --body "Closes #11 and more"
ok_if "pr edit succeeds" test "$code" -eq 0
fake "$d" pr view "$n" --json body --jq .body
ok_if "pr edit replaces the body" test "$out" = "Closes #11 and more"
rm -rf "$d"

d="$(new_scenario)"
fake "$d" pr view --json number --jq .number
ok_if "pr view with no number and no PR for the branch exits non-zero" test "$code" -ne 0
fake "$d" pr view 7 --json number,headRefName --jq '.headRefName'
ok_if "canned PRs still view by number" test "$out" = "add-note-tags"
fake "$d" pr list --json number --jq '.[].number'
ok_if "pr list includes canned PRs" test "$out" = "7"
rm -rf "$d"

# --- runs that wait for a PR to open or merge ---

# new_ship_scenario: no PR yet. Run 4001 (PR checks) starts when a PR opens for
# add-note-tags; run 4002 (main) starts when that PR merges.
new_ship_scenario() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/runs/4001" "$dir/runs/4002" "$dir/prs"
  printf 'example-org/notes-api\n' > "$dir/repo"
  printf '12\n' > "$dir/next-pr"
  cat > "$dir/issues.json" <<'JSON'
[{"number": 11, "title": "Normalize note tags", "state": "OPEN", "body": "", "url": "https://github.com/example-org/notes-api/issues/11"}]
JSON
  cat > "$dir/runs/4001/run.json" <<'JSON'
{"databaseId": 4001, "workflowName": "CI", "path": ".github/workflows/ci.yml",
 "headBranch": "add-note-tags", "headSha": "2222222222222222222222222222222222222222",
 "event": "pull_request", "displayTitle": "Normalize note tags", "startsOn": "pr-open:add-note-tags",
 "url": "https://github.com/example-org/notes-api/actions/runs/4001"}
JSON
  cat > "$dir/runs/4001/timeline.jsonl" <<'JSONL'
{"status": "queued", "conclusion": "", "jobs": []}
{"status": "completed", "conclusion": "success", "jobs": [{"databaseId": 41, "name": "test", "status": "completed", "conclusion": "success", "steps": []}]}
JSONL
  cat > "$dir/runs/4002/run.json" <<'JSON'
{"databaseId": 4002, "workflowName": "CI", "path": ".github/workflows/ci.yml",
 "headBranch": "main", "headSha": "3333333333333333333333333333333333333333",
 "event": "push", "displayTitle": "Normalize note tags (#12)", "startsOn": "merge:add-note-tags",
 "url": "https://github.com/example-org/notes-api/actions/runs/4002"}
JSON
  cat > "$dir/runs/4002/timeline.jsonl" <<'JSONL'
{"status": "queued", "conclusion": "", "jobs": []}
{"status": "in_progress", "conclusion": "", "jobs": []}
{"status": "completed", "conclusion": "success", "jobs": []}
JSONL
  echo "$dir"
}

d="$(new_ship_scenario)"
fake "$d" run list --json databaseId --jq 'length'
ok_if "a run waiting for its PR is not listed before the PR opens" test "$out" = "0"
fake "$d" run view 4001 --json status
ok_if "a run waiting for its PR can't be viewed yet" test "$code" -ne 0
fake "$d" pr create --title "Normalize note tags" --body "Closes #11" --head add-note-tags
ok_if "the created PR takes the scenario's next number" test "$out" = "https://github.com/example-org/notes-api/pull/12"
fake "$d" run list --json databaseId,status --jq '.[] | "\(.databaseId) \(.status)"'
ok_if "after the PR opens its run starts at its first state" test "$out" = "4001 queued"
fake "$d" pr checks 12
ok_if "pr checks on the created PR: done after the second read" test "$code" -eq 0
ok_if "pr checks on the created PR: job listed" has "test"
fake "$d" run view 4002 --json status
ok_if "the main run has not started before the merge" test "$code" -ne 0
rm -rf "$d"

# --- merging ---

d="$(new_ship_scenario)"
fake "$d" pr create --title "Normalize note tags" --body "Closes #11" --head add-note-tags
fake "$d" pr merge 12 --squash
ok_if "pr merge succeeds" test "$code" -eq 0
ok_if "pr merge says what it did" has "Squashed and merged pull request #12"
ok_if "pr merge is logged" logged "$d" "gh pr merge 12 --squash"
fake "$d" pr view 12 --json state,mergeCommit --jq '.state + " " + .mergeCommit.oid'
ok_if "merged PR is MERGED with the main run's commit" test "$out" = "MERGED 3333333333333333333333333333333333333333"
fake "$d" run list --branch main --json databaseId,status --jq '.[] | "\(.databaseId) \(.status)"'
ok_if "after the merge the main run starts at its first state" test "$out" = "4002 queued"
fake "$d" run view 4002 --json status
ok_if "the main run then advances" test "$out" = '{"status":"in_progress"}'
fake "$d" issue view 11 --json state --jq .state
ok_if "a closing keyword in the body closes the issue on merge" test "$out" = "CLOSED"
fake "$d" pr merge 12 --squash
ok_if "merging an already-merged PR exits non-zero" test "$code" -ne 0
rm -rf "$d"

d="$(new_ship_scenario)"
fake "$d" pr create --title "Normalize note tags" --body "Part of #11" --head add-note-tags
fake "$d" pr merge 12 --squash --auto
ok_if "pr merge --auto is refused (it would only arm auto-merge)" has "--auto is not supported"
fake "$d" pr merge 12 --merge --delete-branch
ok_if "pr merge --merge succeeds" has "Merged pull request #12"
fake "$d" issue view 11 --json state --jq .state
ok_if "no closing keyword: the issue stays open" test "$out" = "OPEN"
fake "$d" issue close 11 --comment "Landed in #12"
ok_if "issue close succeeds" test "$code" -eq 0
fake "$d" issue view 11 --json comments --jq '.comments[].body'
ok_if "issue close --comment adds the comment" test "$out" = "Landed in #12"
ok_if "issue close is logged" logged "$d" "gh issue close 11 --comment Landed in #12"
fake "$d" issue view 11 --json state --jq .state
ok_if "closed issue views as CLOSED" test "$out" = "CLOSED"
fake "$d" issue reopen 11
ok_if "issue reopen succeeds" test "$code" -eq 0
fake "$d" issue view 11 --json state --jq .state
ok_if "reopened issue views as OPEN" test "$out" = "OPEN"
fake "$d" issue close 99
ok_if "closing an unknown issue exits non-zero" test "$code" -ne 0
fake "$d" issue comment 11 --body "Verified live"
ok_if "issue comment prints the comment URL" has "https://github.com/example-org/notes-api/issues/11#issuecomment-"
ok_if "issue comment is logged" logged "$d" "gh issue comment 11 --body Verified live"
fake "$d" issue view 11 --json comments --jq '.comments[-1].body'
ok_if "the comment shows on the issue" test "$out" = "Verified live"
fake "$d" issue comment 99 --body "x"
ok_if "commenting on an unknown issue exits non-zero" test "$code" -ne 0
fake "$d" pr merge 13 --squash
ok_if "merging an unknown PR exits non-zero" test "$code" -ne 0
fake "$d" pr merge 12
ok_if "pr merge without a method exits non-zero" test "$code" -ne 0
fake "$d" workflow list --json name,path,state --jq '.[] | "\(.name) \(.path) \(.state)"'
ok_if "workflow list names the scenario's workflows" test "$out" = "CI .github/workflows/ci.yml active"
rm -rf "$d"

if [[ $failures -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all fake-gh tests passed"
