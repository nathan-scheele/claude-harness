---
type: regex
# No call to the write command at all, dry run included: the dry run comes
# after the approval.
pattern: 'WRITE|DRYRUN'
match: not_contains
target:
  source: file
  path: .notes-db/calls.log
---
