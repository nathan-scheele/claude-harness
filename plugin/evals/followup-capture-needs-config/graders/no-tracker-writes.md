---
type: regex
target: {source: file, path: .fake-gh/calls.log}
pattern: 'gh (?:issue (?:create|comment|edit|close|reopen)|pr (?:comment|edit))\b'
match: not_contains
arm: both
---
With no Project config, no caller writes to the tracker: no issue filed, edited or commented on, and no PR comment or edit.
