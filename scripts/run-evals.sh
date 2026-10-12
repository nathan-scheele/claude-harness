#!/usr/bin/env bash
# Run the Harness eval suite against the plugin with a no-plugin baseline arm,
# and fail unless every case passes and the plugin beats the baseline.
# Runs real Claude sessions on your credentials and needs jq. Extra args go to `claude plugin eval`
# (e.g. --case structured-decision --runs 1). Bash, Write and Edit are granted to the
# run but reach only cases that list them in their own allowed_tools.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/plugin/evals/results"  # gitignored
mkdir -p "$OUT"

claude plugin eval "$ROOT/plugin" \
  --trust-plugin --scaffold --no-publish --threshold 1 \
  --allow-tools Bash Write Edit \
  --json "$OUT/last-run.json" "$@"

jq -e '.aggregates.meanDelta > 0' "$OUT/last-run.json" >/dev/null || {
  echo "run-evals: plugin did not beat the no-plugin baseline (meanDelta $(jq '.aggregates.meanDelta' "$OUT/last-run.json"))"
  exit 1
}
echo "run-evals: passed; meanDelta $(jq '.aggregates.meanDelta' "$OUT/last-run.json")"
