#!/usr/bin/env bash
# The shared integration-reviewer fixture, with the batched sync: see
# ../fixtures/integration-reviewer-repo.sh.
set -euo pipefail
bash "$(dirname "$0")/../fixtures/integration-reviewer-repo.sh" --clean
