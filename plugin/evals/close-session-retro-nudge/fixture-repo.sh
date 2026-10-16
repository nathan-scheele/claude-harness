#!/usr/bin/env bash
# Same repo as close-session-clean: the feature branch was pushed and
# squash-merged, so closing out is "safe to clear".
set -euo pipefail
bash "$(dirname "$0")/../close-session-clean/fixture-repo.sh"
