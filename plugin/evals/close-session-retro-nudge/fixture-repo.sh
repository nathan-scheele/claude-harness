#!/usr/bin/env bash
# The shared landed fixture (../fixtures/close-session-landed-repo.sh): the
# feature branch was pushed and squash-merged, so closing out is "safe to clear".
set -euo pipefail
bash "$(dirname "$0")/../fixtures/close-session-landed-repo.sh"
