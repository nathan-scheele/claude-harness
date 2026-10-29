---
type: regex
# n01-n12 already pass the checklist; no write may touch them.
pattern: 'WRITE[^\n]*ids=[^\n]*\b(?:n0[1-9]|n1[0-2])\b'
match: not_contains
target:
  source: file
  path: .notes-db/calls.log
---
