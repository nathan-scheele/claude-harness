---
# Issue 42 writes no data, so the hard gate in 43's prompt must come from its
# production write, not from a rule that gates every prompt.
type: regex
target: {source: file, path: .lanes/tags-v2/42.md}
pattern: 'hard gate'
flags: i
match: not_contains
arm: both
---
The prompt for 42 carries no hard gate.
