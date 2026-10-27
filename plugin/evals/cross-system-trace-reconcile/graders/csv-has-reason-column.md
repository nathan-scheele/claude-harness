---
type: regex
# The header row (the file's first line) has a reason column.
pattern: '^[^\n]*\breason\b'
flags: i
target: {source: file, path: extracts/notes-vs-search.csv}
---
