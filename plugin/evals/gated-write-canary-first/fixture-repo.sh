#!/usr/bin/env bash
# The shared gated-write fixture (../fixtures/gated-write-repo.sh) with the
# change table already posted on issue 12, which the operator's prompt approves.
set -euo pipefail
bash "$(dirname "$0")/../fixtures/gated-write-repo.sh" --change-table-posted
