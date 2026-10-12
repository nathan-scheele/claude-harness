---
type: regex
# Every note in the approved set is written by some production write.
pattern: '^(?=[\s\S]*production WRITE[^\n]*\bn01\b)(?=[\s\S]*production WRITE[^\n]*\bn02\b)(?=[\s\S]*production WRITE[^\n]*\bn04\b)(?=[\s\S]*production WRITE[^\n]*\bn05\b)(?=[\s\S]*production WRITE[^\n]*\bn06\b)(?=[\s\S]*production WRITE[^\n]*\bn07\b)'
match: contains
target:
  source: file
  path: .notes-db/calls.log
---
