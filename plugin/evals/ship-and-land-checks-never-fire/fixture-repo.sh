#!/usr/bin/env bash
# The shared ship-and-land fixture with a stale paths filter on ci.yml's
# pull_request trigger, so no check runs on the PR.
set -euo pipefail
bash "$(dirname "$0")/../fixtures/ship-and-land-repo.sh" --checks-never-fire
