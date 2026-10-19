---
type: regex
# n15 (legacy status, risky), n16 (legal hold, skip) and n17 (no owner, risky)
# must never be written, not even n16's tempting case fix.
pattern: 'WRITE[^\n]*ids=[^\n]*\b(?:n15|n16|n17)\b'
match: not_contains
target:
  source: file
  path: .notes-db/calls.log
---
