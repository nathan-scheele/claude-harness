#!/usr/bin/env bash
# The shared private-api-recon fixture with `## Data connectors` unset: see
# ../fixtures/private-api-recon-repo.sh.
set -euo pipefail
bash "$(dirname "$0")/../fixtures/private-api-recon-repo.sh" --connectors-unset
