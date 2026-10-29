#!/usr/bin/env bash
# The shared cross-system-trace fixture: see ../fixtures/cross-system-trace-repo.sh.
set -euo pipefail
bash "$(dirname "$0")/../fixtures/cross-system-trace-repo.sh"
