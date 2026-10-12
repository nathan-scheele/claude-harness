---
type: regex
pattern: 'WRITE'
match: not_contains
target:
  source: file
  path: .notes-db/calls.log
---
