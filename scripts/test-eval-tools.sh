#!/usr/bin/env bash
# Tests for the eval debugging tools: scripts/save-eval-traces.sh (keeps each
# run's trace after `claude plugin eval` finishes) and scripts/check-graders.mjs
# (re-grades saved traces offline). Each case builds a throwaway runner result
# and trace, runs the tool and asserts on its output and the files it leaves.
# Then run-evals.sh's lock, with a fake claude. Last, two checks over the real
# cases: every grader parses, and every skill or subagent that stops for setup
# has a needs-config case.
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

# temp_run <trace text> [<workspace file>=<content>...]: a stand-in for one
# eval run's temp dir, laid out as the runner leaves it with --keep-temp (out/
# plus a sealed/ dir of mode 000 holding the agent's home, workspace in
# home/cwd).
temp_run() {
  local dir ws kv
  dir="$(mktemp -d "$WORK/e-XXXXXX")"
  ws="$dir/sealed/home/cwd"
  mkdir -p "$dir/out" "$ws"
  printf '%s\n' "$1" > "$dir/out/trace.jsonl"
  printf '{"tool":"new_page"}\n' > "$dir/out/mock-calls.jsonl"
  shift
  for kv in "$@"; do
    mkdir -p "$(dirname "$ws/${kv%%=*}")"
    printf '%s\n' "${kv#*=}" > "$ws/${kv%%=*}"
  done
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

F1="$(temp_run '{"type":"result","result":"files"}' '.notes-db/calls.log=production READ list' 'notes/a b.md=Status: done')"
cat > "$WORK/files.json" <<JSON
{"cases": [{"name": "files-case",
  "graders": [
    {"name": "log", "type": "regex", "config": {"pattern": "READ", "target": {"source": "file", "path": ".notes-db/calls.log"}}},
    {"name": "spaced", "type": "regex", "config": {"pattern": "done", "target": {"source": "file", "path": "notes/a b.md"}}},
    {"name": "extract", "type": "file_exists", "config": {"path": "extracts/x.csv", "exists": true}},
    {"name": "escape", "type": "regex", "config": {"pattern": "x", "target": {"source": "file", "path": "../../outside.txt"}}},
    {"name": "said", "type": "regex", "config": {"pattern": "x", "target": "last_message"}}
  ],
  "arms": {"with": [{"tracePath": "$F1/out/trace.jsonl", "graders": []}]}}]}
JSON
printf 'secret\n' > "$WORK/outside.txt"
out="$(/bin/bash "$SAVE" "$WORK/files.json" "$WORK/traces" 2>&1)"
code=$?
ok_if "saves the workspace files the case's graders read" grep -qF 'production READ list' "$WORK/traces/files-case/with-1/workspace/.notes-db/calls.log"
ok_if "a path with a space" grep -qF 'Status: done' "$WORK/traces/files-case/with-1/workspace/notes/a b.md"
ok_if "a grader file the run didn't make is left out, not an error" test "$code" -eq 0 -a ! -e "$WORK/traces/files-case/with-1/workspace/extracts/x.csv"
ok_if "never copies a path outside the workspace" test -z "$(find "$WORK/traces/files-case" -name outside.txt)"
ok_if "still removes the temp dir" test ! -e "$F1"

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
grader() { printf -- '---\n%s\n---\n%s' "$2" "${3:-}" > "$CASE/graders/$1.md"; }
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
focus: last_message" "PASS if the message greets the operator. GREETCHECK"
grader judge-trace "type: llm
focus: trace" "PASS if a write command ran. TRACECHECK"
grader judge-split "type: llm
focus: last_message" "SPLITCHECK"
grader judge-garbled "type: llm
focus: last_message" "GARBLECHECK"
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
printf '[{"name":"greets","passed":false},{"name":"no-write","passed":true},{"name":"judge","passed":false}]\n' > "$TR/with-1/graders.json"
mkdir -p "$TR/with-1/workspace/.notes-db" "$TR/without-1/workspace"
printf 'production READ list\n' > "$TR/with-1/workspace/.notes-db/calls.log"
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
ok_if "regex on a saved workspace file; one the run didn't make reads as empty" test "$(row file-log)" = "PASS FAIL"
ok_if "skips llm graders without --llm, and file_exists" test "$(row judge) $(row exists)" = "skip skip skip skip"
ok_if "says how to grade the llm ones" has "--llm"
ok_if "explains the * marker" has "runner"

OLD="$WORK/old-traces/demo-grading/with-1"
mkdir -p "$OLD" && cp "$TR/with-1/trace.jsonl" "$OLD/"
out="$(node "$HERE/check-graders.mjs" "$CASE" "$WORK/old-traces/demo-grading" 2>&1)"
ok_if "skips file targets for traces saved without the workspace" test "$(row file-log)" = "skip"

# A stand-in judge: reads the prompt on stdin, logs it, and votes by marker.
cat > "$WORK/judge.sh" <<'SH'
#!/usr/bin/env bash
in="$(cat)"
dir="$(dirname "$0")"
printf '%s\n=====\n' "$in" >> "$dir/judge-input.log"
case "$in" in
  *GREETCHECK*) grep -q 'Hi THERE' <<<"$in" && echo "PASS: greets" || echo "FAIL: no greeting" ;;
  *TRACECHECK*) grep -q 'set-status' <<<"$in" && echo "PASS" || echo "FAIL" ;;
  *SPLITCHECK*) n=$(( $(cat "$dir/split-count" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$dir/split-count"
                [ $((n % 3)) -eq 1 ] && echo "PASS" || echo "FAIL" ;;
  *) echo "I am not sure." ;;
esac
SH
chmod +x "$WORK/judge.sh"
out="$(CHECK_GRADERS_JUDGE="$WORK/judge.sh" node "$HERE/check-graders.mjs" "$CASE" "$TR" --llm 2>&1)"
code=$?
ok_if "--llm: exits 0" test "$code" -eq 0
ok_if "--llm: judges the last message; marks a runner disagreement" test "$(row judge)" = "PASS* FAIL"
ok_if "--llm: focus trace shows the judge the trace" test "$(row judge-trace)" = "FAIL PASS"
ok_if "--llm: three votes, majority wins, a split shows the count" test "$(row judge-split)" = "FAIL(1/3) FAIL(1/3)"
ok_if "--llm: a judge with no verdict is a skip, not a pass" test "$(row judge-garbled)" = "skip skip"
ok_if "--llm: the judge sees the grader's conditions" grep -qF 'PASS if the message greets the operator.' "$WORK/judge-input.log"
ok_if "--llm: a failed cell says why, in the judge's words" has "why judge without-1: no greeting"
ok_if "--llm: a passing cell gives no reason" test -z "$(grep -F 'why judge with-1' <<<"$out")"
ok_if "--llm: still skips file_exists" test "$(row exists)" = "skip skip"

out="$(node "$HERE/check-graders.mjs" "$CASE" "$WORK/no-such-dir" 2>&1)"
code=$?
ok_if "no traces: exits 2 and says how to get them" test "$code" -eq 2 -a -n "$(grep -F 'run-evals.sh' <<<"$out")"

echo "# run-evals.sh runs one at a time"
# A copy outside git, so its lock falls back to its own results dir, with a
# fake claude that only records the call.
R="$WORK/lock-repo"
mkdir -p "$R/scripts" "$WORK/fake-bin"
cp "$HERE/run-evals.sh" "$R/scripts/"
printf '#!/bin/sh\necho called >> "%s/claude-calls"\n' "$WORK" > "$WORK/fake-bin/claude"
chmod +x "$WORK/fake-bin/claude"
LOCK="$R/plugin/evals/results/run-evals.lock"
evals() { PATH="$WORK/fake-bin:$PATH" bash "$R/scripts/run-evals.sh" --case x 2>&1; }

sh -c 'exit 0' & gone=$!
wait "$gone"
mkdir -p "$LOCK" && echo "$gone" > "$LOCK/pid"
out="$(evals)"
ok_if "takes over a lock whose holder has exited, and releases it" test "$(cat "$WORK/claude-calls" 2>/dev/null)" = called -a ! -e "$LOCK"

rm -f "$WORK/claude-calls"
sleep 30 & holder=$!
mkdir -p "$LOCK" && echo "$holder" > "$LOCK/pid"
evals > "$WORK/lock-wait.log" & run=$!
sleep 2
out="$(cat "$WORK/lock-wait.log")"
ok_if "waits while another run holds the lock" test ! -e "$WORK/claude-calls" -a -n "$(grep -F 'waiting for another eval run' <<<"$out")"
kill "$holder"
wait "$holder" 2>/dev/null
wait "$run"
out="$(cat "$WORK/lock-wait.log")"
ok_if "runs once the holder exits, and releases the lock" test -e "$WORK/claude-calls" -a ! -e "$LOCK"

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

echo "# every skill or subagent that stops for setup has a needs-config case"
# One that sends the operator to /harness:setup-harness when Project config is
# missing needs an eval case <name>-needs-config or <name>-needs-setup proving
# it stops. Exempt: setup-harness writes the config, standards defines the rule.
EXEMPT=" setup-harness standards "
# Known gaps, whose cases #53 adds. Remove a name when its case lands; the
# test fails if a listed name already has one.
KNOWN_GAPS=" gated-write ship-and-land "
missing="" stale=""
for f in "$HERE"/../plugin/skills/*/SKILL.md "$HERE"/../plugin/agents/*.md; do
  case "$f" in */SKILL.md) n="$(basename "$(dirname "$f")")" ;; *) n="$(basename "$f" .md)" ;; esac
  grep -q 'setup-harness' "$f" || continue
  [[ "$EXEMPT" == *" $n "* ]] && continue
  if [[ -f "$HERE/../plugin/evals/$n-needs-config/case.yaml" || -f "$HERE/../plugin/evals/$n-needs-setup/case.yaml" ]]; then
    [[ "$KNOWN_GAPS" == *" $n "* ]] && stale="$stale $n"
  else
    [[ "$KNOWN_GAPS" == *" $n "* ]] || missing="$missing $n"
  fi
done
out="missing a needs-config case:$missing"
ok_if "each has a <name>-needs-config or -needs-setup case" test -z "$missing"
out="has its case now, remove from KNOWN_GAPS:$stale"
ok_if "KNOWN_GAPS lists only real gaps" test -z "$stale"

if [[ $failures -gt 0 ]]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all eval-tools tests passed"
