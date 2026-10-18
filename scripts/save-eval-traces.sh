#!/usr/bin/env bash
# Keeps each eval run's trace after `claude plugin eval` finishes, so a failed
# grader can be diagnosed (and re-graded with scripts/check-graders.mjs)
# without rerunning the case.
#
# usage: save-eval-traces.sh <last-run.json> <dest-dir> [--keep-temp]
#
# For every run in the runner's result JSON it copies the run's trace.jsonl and
# mock-calls.jsonl, and writes the runner's grader verdicts as graders.json, to
# <dest-dir>/<case>/<arm>-<n>/ (replacing that case's earlier traces). The run
# must have used --keep-temp; this script then removes those temp dirs
# (/…/e-XXXX, whose sealed/ dir is mode 000, hence the chmod) unless it is
# given --keep-temp too. Needs jq.
set -uo pipefail

result="${1:?usage: save-eval-traces.sh <last-run.json> <dest-dir> [--keep-temp]}"
dest="${2:?usage: save-eval-traces.sh <last-run.json> <dest-dir> [--keep-temp]}"
keep="${3:-}"

for c in $(jq -r '.cases[].name' "$result"); do
  rm -rf "${dest:?}/$c"
  mkdir -p "$dest/$c"
  # One line per run: arm, run number (from 1), trace path.
  jq -r --arg c "$c" '.cases[] | select(.name == $c) | .arms | to_entries[]
    | .key as $arm | .value | to_entries[] | "\($arm)\t\(.key + 1)\t\(.value.tracePath // "")"' "$result" |
    while IFS=$'\t' read -r arm n trace; do
      run="$dest/$c/$arm-$n"
      mkdir -p "$run"
      jq --arg c "$c" --arg arm "$arm" --argjson i $((n - 1)) \
        '.cases[] | select(.name == $c) | .arms[$arm][$i].graders // []' "$result" > "$run/graders.json"
      if [[ ! -f "$trace" ]]; then
        echo "save-eval-traces: $c $arm-$n: no trace at ${trace:-(none)}; was the run started with --keep-temp?"
        continue
      fi
      cp "$trace" "$run/trace.jsonl"
      [[ -f "$(dirname "$trace")/mock-calls.jsonl" ]] && cp "$(dirname "$trace")/mock-calls.jsonl" "$run/"
      tmp="$(dirname "$(dirname "$trace")")"
      if [[ "$keep" != --keep-temp && "$(basename "$tmp")" == e-* && "$trace" == "$tmp/out/trace.jsonl" ]]; then
        chmod -R u+rwx "$tmp" && rm -rf "$tmp"
      fi
    done
  echo "save-eval-traces: $c traces in $dest/$c"
done
