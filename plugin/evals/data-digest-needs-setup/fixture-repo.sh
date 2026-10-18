#!/usr/bin/env bash
# The shared data-digest fixture (../fixtures/data-digest-repo.sh) with
# `## Data connectors` unset.
set -euo pipefail
bash "$(dirname "$0")/../fixtures/data-digest-repo.sh" --connectors-unset
