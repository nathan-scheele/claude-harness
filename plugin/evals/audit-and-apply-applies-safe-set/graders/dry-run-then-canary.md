---
type: regex
# From the start of the call log: no write before a dry run, and the first
# write touches 1-3 notes (gated-write's canary).
pattern: '^(?:(?!production WRITE)[\s\S])*production DRYRUN(?:(?!production WRITE)[\s\S])*production WRITE set-status \w+ n=[1-3] '
match: contains
target:
  source: file
  path: .notes-db/calls.log
---
