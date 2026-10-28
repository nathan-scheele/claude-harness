#!/usr/bin/env bash
# The audit-and-apply fixture with `## Data connectors` unset: see
# ../fixtures/audit-and-apply-repo.sh.
set -euo pipefail
bash "$(dirname "$0")/../fixtures/audit-and-apply-repo.sh" --connectors-unset
