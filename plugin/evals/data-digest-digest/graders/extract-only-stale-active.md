---
type: regex
# n03 is old but archived; n08 is active but edited in 2024; n13 is active,
# edited in 2024.
pattern: '\bn(?:03|08|13)\b'
match: not_contains
target:
  source: file
  path: extracts/stale-notes.csv
---
