#!/usr/bin/env bash
# The shared stakeholder-message fixture (../fixtures/stakeholder-message-repo.sh),
# with a later comment on issue 12: the backfill has run.
set -euo pipefail
bash "$(dirname "$0")/../fixtures/stakeholder-message-repo.sh" --backfill-done
