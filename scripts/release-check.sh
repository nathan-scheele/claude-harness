#!/usr/bin/env bash
# Fail unless the plugin's version is the newest entry in CHANGELOG.md and,
# when a tag is given, the tag is that version with a "v" prefix. Run it
# before tagging a release.
#
# Usage: scripts/release-check.sh [repo-dir] [tag]
set -euo pipefail

ROOT="${1:-.}"
TAG="${2:-}"
MANIFEST="$ROOT/plugin/.claude-plugin/plugin.json"
CHANGELOG="$ROOT/CHANGELOG.md"

# Top-level keys are indented two spaces; deeper "version" keys are ignored.
version="$(sed -n 's/^  "version":[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" | head -n 1)"
if [[ -z "$version" ]]; then
  echo "release-check: no version in $MANIFEST" >&2
  exit 1
fi

if [[ ! -f "$CHANGELOG" ]]; then
  echo "release-check: $CHANGELOG is missing" >&2
  exit 1
fi

# Entries are "## <version>" headings, newest first, optionally followed by " - <date>".
newest="$(sed -n 's/^## \([^ ]*\).*/\1/p' "$CHANGELOG" | head -n 1)"
if [[ "$newest" != "$version" ]]; then
  echo "release-check: plugin version is $version but the newest CHANGELOG.md entry is ${newest:-(none)}" >&2
  exit 1
fi

if [[ -n "$TAG" && "$TAG" != "v$version" ]]; then
  echo "release-check: tag $TAG does not match plugin version $version (want v$version)" >&2
  exit 1
fi

echo "release-check: $version${TAG:+ ($TAG)} ok"
