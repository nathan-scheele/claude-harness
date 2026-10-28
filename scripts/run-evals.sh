#!/usr/bin/env bash
# Run the Harness eval suite against the plugin with a no-plugin baseline arm,
# and fail unless every case passes and the plugin beats the baseline.
# Runs real Claude sessions on your credentials and needs jq. Extra args go to `claude plugin eval`
# (e.g. --case structured-decision --runs 1; one --case per call); --help prints its options.
# Bash, Write and Edit are granted to the run but reach only cases that list them in their own
# allowed_tools. Every run's trace is saved to plugin/evals/results/traces/<case>/<arm>-<n>/
# (save-eval-traces.sh); re-grade them offline with scripts/check-graders.mjs.
# The runner's full output goes to plugin/evals/results/run.log; this prints one
# line per run (scored graders passed) and each failing grader of a with-plugin run.
# Runs one at a time across the repo's worktrees: a second run waits for the first.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/plugin/evals/results"  # gitignored
mkdir -p "$OUT"

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  exec claude plugin eval --help
fi
keep=""
for arg in "$@"; do [[ "$arg" == --keep-temp ]] && keep=--keep-temp; done

# One eval run at a time across this repo's worktrees: runs from parallel Lanes
# stall each other's sessions. The lock sits in the git dir every worktree
# shares; a lock whose holder has exited is taken over.
lock="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || echo "$OUT")/run-evals.lock"
waiting=""
until mkdir "$lock" 2>/dev/null; do
  holder="$(cat "$lock/pid" 2>/dev/null || true)"
  if [[ -n "$holder" ]] && ! kill -0 "$holder" 2>/dev/null; then rm -rf "$lock"; continue; fi
  [[ -n "$waiting" ]] || echo "run-evals: waiting for another eval run to finish (pid ${holder:-?}, $lock)" >&2
  waiting=1
  sleep 5
done
echo $$ > "$lock/pid"
trap 'rm -rf "$lock"' EXIT

rm -f "$OUT/last-run.json"
log="$OUT/run.log"
echo "run-evals: running; full output in $log"
status=0
claude plugin eval "$ROOT/plugin" \
  --trust-plugin --scaffold --no-publish --threshold 1 \
  --allow-tools Bash Write Edit \
  --keep-temp \
  --json "$OUT/last-run.json" "$@" > "$log" 2>&1 || status=$?

if [[ ! -f "$OUT/last-run.json" ]]; then
  tail -n 20 "$log"
  exit "$((status == 0 ? 1 : status))"
fi
"$ROOT/scripts/save-eval-traces.sh" "$OUT/last-run.json" "$OUT/traces" $keep >> "$log"

# One line per run with its scored graders passed, then each failing scored
# grader of a with-plugin run (the baseline is expected to fail).
jq -r '.cases[] | .name as $c | .arms | to_entries[] | .key as $arm | .value | to_entries[]
  | [.value.graders[]? | select(.scored != false)] as $g
  | "\($c) \($arm)-\(.key + 1): \([$g[] | select(.passed)] | length)/\($g | length)",
    (if $arm == "with" then $g[] | select(.passed | not)
      | "  FAIL \(.name): \(.explanation // "" | tostring | gsub("\\s+"; " ") | .[0:160])" else empty end)' "$OUT/last-run.json"
echo "run-evals: traces in $OUT/traces (re-grade with scripts/check-graders.mjs <case>)"
[[ $status -eq 0 ]] || exit "$status"

jq -e '.aggregates.meanDelta > 0' "$OUT/last-run.json" >/dev/null || {
  echo "run-evals: plugin did not beat the no-plugin baseline (meanDelta $(jq '.aggregates.meanDelta' "$OUT/last-run.json"))"
  exit 1
}
echo "run-evals: passed; meanDelta $(jq '.aggregates.meanDelta' "$OUT/last-run.json")"
