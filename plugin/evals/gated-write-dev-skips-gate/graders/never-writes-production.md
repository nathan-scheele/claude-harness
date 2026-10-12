---
type: regex
pattern: 'production (?:WRITE|DRYRUN)'
match: not_contains
target:
  source: file
  path: .notes-db/calls.log
---
