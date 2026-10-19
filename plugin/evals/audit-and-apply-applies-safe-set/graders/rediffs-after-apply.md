---
type: regex
# After the last write, a read of every note: an unfiltered list, or a get that
# includes the notes left alone. gated-write's re-check of its own scope (the
# safe set) usually reads only those four notes, but one that lists every note
# passes this too: the log can't tell the two apart.
pattern: 'production WRITE(?![\s\S]*production WRITE)[\s\S]*production READ (?:list *\n|get [^\n]*\bn1[5-7]\b)'
match: contains
target:
  source: file
  path: .notes-db/calls.log
---
