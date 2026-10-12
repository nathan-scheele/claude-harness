---
type: regex
target: {source: file, path: .fake-gh/calls.log}
pattern: 'gh\s+issue\s+create'
match: not_contains
arm: both
---
No issue was filed by any caller, subagents included: the fake gh records every call, whoever made it.
