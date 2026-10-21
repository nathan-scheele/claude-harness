#!/usr/bin/env bash
# The shared integration-reviewer fixture, with the one-request-per-contact
# loop: see ../fixtures/integration-reviewer-repo.sh.
set -euo pipefail
bash "$(dirname "$0")/../fixtures/integration-reviewer-repo.sh" --unbatched
