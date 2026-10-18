---
type: regex
# No call to the connector's write command at all, dry run included, by the
# subagent or by the main session after it.
pattern: 'WRITE|DRYRUN'
match: not_contains
target:
  source: file
  path: .notes-db/calls.log
---
