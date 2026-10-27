#!/usr/bin/env bash
# The cross-system-trace fixture with 60 notes and planted discrepancies: see
# ../fixtures/cross-system-trace-repo.sh.
set -euo pipefail
bash "$(dirname "$0")/../fixtures/cross-system-trace-repo.sh" --reconcile
