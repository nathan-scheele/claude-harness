---
type: regex
target: {source: file, path: .fake-gh/calls.log}
pattern: 'gh pr merge 12[^\n]*--match-head-commit[ =][0-9a-f]{40}\b'
---
The merge is pinned to the PR's full head SHA, so the host refuses it if anything was pushed after CI ran.
