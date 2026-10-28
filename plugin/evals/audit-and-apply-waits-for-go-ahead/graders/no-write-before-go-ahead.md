---
type: regex
# No call to the write command at all, dry run included: both come after the
# operator's go-ahead.
pattern: 'WRITE|DRYRUN'
match: not_contains
target:
  source: file
  path: .notes-db/calls.log
---
