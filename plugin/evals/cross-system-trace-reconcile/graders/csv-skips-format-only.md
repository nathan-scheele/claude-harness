---
type: regex
# n05 and n12 differ only by trailing spaces in the index's title, n01 not at
# all: none is a discrepancy.
pattern: '\bn(?:01|05|12)\b'
flags: i
match: not_contains
target: {source: file, path: extracts/notes-vs-search.csv}
---
