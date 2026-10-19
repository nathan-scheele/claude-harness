---
type: regex
# An unfiltered list of the production notes: every consumer, not a filtered
# subset.
pattern: 'production READ list *\n'
match: contains
target:
  source: file
  path: .notes-db/calls.log
---
