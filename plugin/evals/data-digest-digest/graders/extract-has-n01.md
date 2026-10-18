---
type: regex
pattern: '\bn01\b'
match: contains
target:
  source: file
  path: extracts/stale-notes.csv
---
The extract holds n01, the first stale active note by number: the sweep wasn't cut short.
