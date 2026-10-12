---
type: regex
# n03 (already archived) and n08-n12 (edited since 2024) are out of scope.
pattern: 'WRITE[^\n]*ids=[^\n]*\b(?:n03|n08|n09|n10|n11|n12)\b'
match: not_contains
target:
  source: file
  path: .notes-db/calls.log
---
