#!/usr/bin/env bash
# The shared followup-capture fixture (../fixtures/followup-capture-repo.sh),
# without a Project config.
set -euo pipefail
bash "$(dirname "$0")/../fixtures/followup-capture-repo.sh" --no-config
