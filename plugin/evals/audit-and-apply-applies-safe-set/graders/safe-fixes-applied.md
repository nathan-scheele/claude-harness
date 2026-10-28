---
type: regex
# The safe set, each to its own lower-case value: n13 and n18 to active, n14
# and n19 to archived.
pattern: '^(?=[\s\S]*production WRITE set-status active [^\n]*\bn13\b)(?=[\s\S]*production WRITE set-status active [^\n]*\bn18\b)(?=[\s\S]*production WRITE set-status archived [^\n]*\bn14\b)(?=[\s\S]*production WRITE set-status archived [^\n]*\bn19\b)'
match: contains
target:
  source: file
  path: .notes-db/calls.log
---
