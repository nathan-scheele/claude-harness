#!/usr/bin/env bash
# Run the Harness eval suite against the plugin with a no-plugin baseline arm,
# and fail unless every case passes and the plugin beats the baseline.
# Runs real Claude sessions on your credentials and needs jq. Extra args go to `claude plugin eval`
# (e.g. --case structured-decision --runs 1; one --case per call); --help prints its options.
# Bash, Write and Edit are granted to the run but reach only cases that list them in their own
# allowed_tools. Every run's trace is saved to plugin/evals/results/traces/<case>/<arm>-<n>/
# (save-eval-traces.sh); re-grade them offline with scripts/check-graders.mjs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/plugin/evals/results"  # gitignored
mkdir -p "$OUT"

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  exec claude plugin eval --help
fi
keep=""
for arg in "$@"; do [[ "$arg" == --keep-temp ]] && keep=--keep-temp; done

rm -f "$OUT/last-run.json"
status=0
claude plugin eval "$ROOT/plugin" \
  --trust-plugin --scaffold --no-publish --threshold 1 \
  --allow-tools Bash Write Edit \
  --keep-temp \
  --json "$OUT/last-run.json" "$@" || status=$?

[[ -f "$OUT/last-run.json" ]] || exit "$((status == 0 ? 1 : status))"
"$ROOT/scripts/save-eval-traces.sh" "$OUT/last-run.json" "$OUT/traces" $keep
[[ $status -eq 0 ]] || exit "$status"

jq -e '.aggregates.meanDelta > 0' "$OUT/last-run.json" >/dev/null || {
  echo "run-evals: plugin did not beat the no-plugin baseline (meanDelta $(jq '.aggregates.meanDelta' "$OUT/last-run.json"))"
  exit 1
}
echo "run-evals: passed; meanDelta $(jq '.aggregates.meanDelta' "$OUT/last-run.json")"
