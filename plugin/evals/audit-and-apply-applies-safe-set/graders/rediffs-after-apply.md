---
type: regex
# After the last write, a read of every note: an unfiltered list, or a get that
# includes the notes left alone. gated-write's own re-check reads only the
# notes it wrote, so this is the audit's re-diff.
pattern: 'production WRITE(?![\s\S]*production WRITE)[\s\S]*production READ (?:list *\n|get [^\n]*\bn1[5-7]\b)'
match: contains
target:
  source: file
  path: .notes-db/calls.log
---
