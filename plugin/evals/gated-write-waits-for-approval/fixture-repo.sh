#!/usr/bin/env bash
# The shared gated-write fixture: see ../fixtures/gated-write-repo.sh.
set -euo pipefail
bash "$(dirname "$0")/../fixtures/gated-write-repo.sh"
