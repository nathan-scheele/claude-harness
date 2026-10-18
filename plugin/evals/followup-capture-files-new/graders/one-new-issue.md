---
type: regex
target: {source: file, path: .fake-gh/calls.log}
pattern: 'gh\s+issue\s+create'
match: count:1
---
Exactly one issue was filed, by any caller.
