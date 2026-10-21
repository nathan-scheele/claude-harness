#!/usr/bin/env bash
# Writes a git wrapper at $1 that works in the eval sandbox, for fixtures whose
# agent needs git. On macOS the sandbox blocks the Command Line Tools behind
# /usr/bin/git, so plain git fails there; the wrapper runs another git, with its
# directory first on PATH so the git-receive-pack a push to a local origin
# spawns is that git's too. Fails the fixture if there is no such git.
#   bash "$(dirname "${BASH_SOURCE[0]}")/sandbox-git.sh" .fake-gh/bin/git
set -euo pipefail

dest="${1:?usage: sandbox-git.sh <wrapper path>}"
mkdir -p "$(dirname "$dest")"
for g in /opt/homebrew/bin/git /usr/local/bin/git "$(command -v git)"; do
  if [[ -x "$g" && ! ( "$(uname)" == Darwin && "$g" == /usr/bin/git ) ]]; then
    printf '#!/bin/sh\nPATH="%s:$PATH" exec "%s" "$@"\n' "$(dirname "$g")" "$g" > "$dest"
    chmod +x "$dest"
    exit 0
  fi
done
echo "fixture: no git usable in the eval sandbox (on macOS, install Homebrew git)" >&2
exit 1
