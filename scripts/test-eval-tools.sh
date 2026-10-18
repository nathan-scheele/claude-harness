#!/usr/bin/env bash
# Tests for the eval debugging tools: scripts/save-eval-traces.sh (keeps each
# run's trace after `claude plugin eval` finishes) and scripts/check-graders.mjs
# (re-grades saved traces offline). Each case builds a throwaway runner result
# and trace, runs the tool and asserts on its output and the files it leaves.
# Needs jq and node. Runs the save script with /bin/bash so macOS CI exercises
# the system bash 3.2.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SAVE="$HERE/save-eval-traces.sh"
failures=0
WORK="$(mktemp -d)"
trap 'chmod -R u+rwx "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT

ok_if() {
  local name="$1"; shift
  if "$@"; then
    echo "ok   - $name"
  else
    echo "FAIL - $name"
    [[ -n "${out:-}" ]] && echo "$out" | sed 's/^/       /'
    failures=$((failures + 1))
  fi
}
has() { grep -qF -- "$1" <<<"$out"; }

# temp_run <trace text>: a stand-in for one eval run's temp dir, laid out as the
# runner leaves it with --keep-temp (out/ plus a sealed/ dir of mode 000).
temp_run() {
  local dir
  dir="$(mktemp -d "$WORK/e-XXXXXX")"
  mkdir -p "$dir/out" "$dir/sealed/home"
  printf '%s\n' "$1" > "$dir/out/trace.jsonl"
  printf '{"tool":"new_page"}\n' > "$dir/out/mock-calls.jsonl"
  chmod 000 "$dir/sealed"
  echo "$dir"
}

echo "# save-eval-traces.sh"
W1="$(temp_run '{"type":"result","result":"with one"}')"
W2="$(temp_run '{"type":"result","result":"with two"}')"
B1="$(temp_run '{"type":"result","result":"without one"}')"
cat > "$WORK/last-run.json" <<JSON
{"cases": [{"name": "demo-case", "arms": {
  "with": [
    {"tracePath": "$W1/out/trace.jsonl", "graders": [{"name": "says-hi", "passed": true}]},
    {"tracePath": "$W2/out/trace.jsonl", "graders": [{"name": "says-hi", "passed": false}]}
  ],
  "without": [
    {"tracePath": "$B1/out/trace.jsonl", "graders": [{"name": "says-hi", "passed": false}]}
  ]}}]}
JSON
mkdir -p "$WORK/traces/demo-case/with-9"
out="$(/bin/bash "$SAVE" "$WORK/last-run.json" "$WORK/traces" 2>&1)"
code=$?
ok_if "exits 0" test "$code" -eq 0
ok_if "copies each run's trace by arm and number" grep -qF 'with two' "$WORK/traces/demo-case/with-2/trace.jsonl"
ok_if "copies the baseline arm too" grep -qF 'without one' "$WORK/traces/demo-case/without-1/trace.jsonl"
ok_if "copies the mock calls" test -s "$WORK/traces/demo-case/with-1/mock-calls.jsonl"
ok_if "keeps the runner's grader verdicts" test "$(jq -r '.[0].passed' "$WORK/traces/demo-case/with-2/graders.json")" = false
ok_if "replaces the case's earlier traces" test ! -e "$WORK/traces/demo-case/with-9"
ok_if "removes the temp dirs, sealed/ included" test ! -e "$W1" -a ! -e "$W2" -a ! -e "$B1"
ok_if "says where the traces went" has "$WORK/traces/demo-case"

K1="$(temp_run '{"type":"result","result":"kept"}')"
cat > "$WORK/keep.json" <<JSON
{"cases": [{"name": "keep-case", "arms": {"with": [{"tracePath": "$K1/out/trace.jsonl", "graders": []}]}}]}
JSON
out="$(/bin/bash "$SAVE" "$WORK/keep.json" "$WORK/traces" --keep-temp 2>&1)"
ok_if "--keep-temp copies but leaves the temp dir" test -e "$K1/out/trace.jsonl" -a -s "$WORK/traces/keep-case/with-1/trace.jsonl"

OTHER="$(mktemp -d "$WORK/not-a-run-XXXXXX")"
mkdir -p "$OTHER/out" && printf '{}\n' > "$OTHER/out/trace.jsonl"
cat > "$WORK/odd.json" <<JSON
{"cases": [{"name": "odd-case", "arms": {"with": [
  {"tracePath": "$OTHER/out/trace.jsonl", "graders": []},
  {"tracePath": "$WORK/e-gone/out/trace.jsonl", "graders": []}
]}}]}
JSON
out="$(/bin/bash "$SAVE" "$WORK/odd.json" "$WORK/traces" 2>&1)"
code=$?
ok_if "never removes a dir that isn't an eval temp dir (e-*)" test -e "$OTHER/out/trace.jsonl"
ok_if "reports a trace that is already gone, and carries on" has "e-gone"
ok_if "a missing trace isn't a failure" test "$code" -eq 0

echo "# check-graders.mjs"
CASE="$WORK/demo-grading"
mkdir -p "$CASE/graders"
grader() { printf -- '---\n%s\n---\n' "$2" > "$CASE/graders/$1.md"; }
grader report-contract "type: regex
target: trace
pattern: 'Status: complete\\\\nMethod:'"
grader no-write "type: regex
target: trace
# a comment line
pattern: '\"command\":\"[^\"]*set-status'
match: not_contains"
grader delegated "type: tool_used
tool: Agent
input_match: '\"subagent_type\"\\s*:\\s*\"(?:harness:)?data-digest\"'
arm: with-only"
grader no-set-status "type: tool_used
tool: Bash
input_match: 'set-status'
min: 0
max: 0"
grader subagent-bash "type: tool_used
tool: Bash
input_match: 'get n01'"
grader greets "type: regex
target: last_message
pattern: 'hi there'
flags: i"
grader two-bash-calls "type: regex
target: trace
pattern: '\"name\":\"Bash\"'
match: count:2"
grader list-before-write "type: tool_order
before: {tool: Bash, input_match: 'list'}
after: {tool: Write, input_match: 'it''s extract'}"
grader mock-new-page "type: regex
target: mock_calls
pattern: 'new_page'"
grader file-log "type: regex
pattern: 'READ'
target:
  source: file
  path: .notes-db/calls.log"
grader judge "type: llm
focus: last_message"
grader exists "type: file_exists
path: extracts/x.csv
exists: true"

TR="$WORK/grading-traces/demo-grading"
mkdir -p "$TR/with-1" "$TR/without-1"
cat > "$TR/with-1/trace.jsonl" <<'JSONL'
{"type":"system","subtype":"init"}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"bin/notes-db list"}}]},"parent_tool_use_id":null}
{"type":"assistant","message":{"content":[{"type":"text","text":"delegating"},{"type":"tool_use","name":"Task","input":{"subagent_type":"harness:data-digest","prompt":"count"}}]},"parent_tool_use_id":null}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"bin/notes-db get n01"}}]},"parent_tool_use_id":"toolu_1"}
{"type":"user","message":{"content":[{"type":"tool_result","content":[{"type":"text","text":"Status: complete\nMethod:\n- `bin/notes-db list`"}]}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Write","input":{"file_path":"it's extract.csv","content":"id"}}]},"parent_tool_use_id":null}
{"type":"result","result":"Hi THERE: 216 active"}
JSONL
printf '{"tool":"new_page"}\n' > "$TR/with-1/mock-calls.jsonl"
printf '[{"name":"greets","passed":false},{"name":"no-write","passed":true}]\n' > "$TR/with-1/graders.json"
cat > "$TR/without-1/trace.jsonl" <<'JSONL'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Write","input":{"file_path":"it's extract.csv","content":"id"}}]},"parent_tool_use_id":null}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"bin/notes-db set-status archived n01"}}]},"parent_tool_use_id":null}
{"type":"result","result":"done"}
JSONL

out="$(node "$HERE/check-graders.mjs" "$CASE" "$TR" 2>&1)"
code=$?
# row <grader>: that grader's cells, one per run (with-1, without-1).
row() { awk -v g="$1" '$1 == g { $1 = ""; sub(/^ /, ""); print; exit }' <<<"$out"; }
ok_if "exits 0" test "$code" -eq 0
ok_if "lists the runs as columns, with-plugin first" test "$(row grader)" = "with-1 without-1"
ok_if "regex on the whole trace" test "$(row report-contract)" = "PASS FAIL"
ok_if "regex not_contains, past comment lines" test "$(row no-write)" = "PASS FAIL"
ok_if "tool_used counts a Task call as Agent" test "$(row delegated)" = "PASS FAIL"
ok_if "tool_used max 0" test "$(row no-set-status)" = "PASS FAIL"
ok_if "tool_used counts subagent calls, min 1 by default" test "$(row subagent-bash)" = "PASS FAIL"
ok_if "regex on the last message, with flags; marks a runner disagreement" test "$(row greets)" = "PASS* FAIL"
ok_if "regex count:N" test "$(row two-bash-calls)" = "PASS FAIL"
ok_if "tool_order with flow maps and '' escapes" test "$(row list-before-write)" = "PASS FAIL"
ok_if "regex on mock calls" test "$(row mock-new-page)" = "PASS FAIL"
ok_if "skips file targets, llm and file_exists" test "$(row file-log) $(row judge) $(row exists)" = "skip skip skip skip skip skip"
ok_if "says why it skipped" has "workspace files aren't saved"
ok_if "explains the * marker" has "runner"

out="$(node "$HERE/check-graders.mjs" "$CASE" "$WORK/no-such-dir" 2>&1)"
code=$?
ok_if "no traces: exits 2 and says how to get them" test "$code" -eq 2 -a -n "$(grep -F 'run-evals.sh' <<<"$out")"

echo "# check-graders.mjs reads every grader in the repo"
mkdir -p "$WORK/empty-run/with-1" && printf '{"type":"result","result":""}\n' > "$WORK/empty-run/with-1/trace.jsonl"
unread=""
for dir in "$HERE"/../plugin/evals/*/graders; do
  c="$(dirname "$dir")"
  out="$(node "$HERE/check-graders.mjs" "$c" "$WORK/empty-run" 2>&1)" || unread="$unread $(basename "$c")"
  grep -q 'unknown' <<<"$out" && unread="$unread $(basename "$c")"
done
out="$unread"
ok_if "parses and runs every case's graders" test -z "$unread"

if [[ $failures -gt 0 ]]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all eval-tools tests passed"
