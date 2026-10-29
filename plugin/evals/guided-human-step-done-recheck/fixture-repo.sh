#!/usr/bin/env bash
# The shared guided-human-step fixture after a session handed over three Human
# steps and the operator did some of them: see ../fixtures/guided-human-step-repo.sh.
set -euo pipefail
bash "$(dirname "$0")/../fixtures/guided-human-step-repo.sh" --resume
