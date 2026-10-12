---
type: regex
pattern: 'staging WRITE set-status archived'
match: contains
target:
  source: file
  path: .notes-db/calls.log
---
