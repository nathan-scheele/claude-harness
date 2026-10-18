---
type: regex
target: {source: file, path: .fake-gh/calls.log}
pattern: 'gh\s+issue\s+create'
match: not_contains
arm: both
---
Issue 48 already covers the finding, so no caller files a new issue.
