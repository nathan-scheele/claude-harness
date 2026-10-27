---
type: regex
# One key from each category: missing in the index (n21), missing in the notes
# database (n61), status mismatch (n30), title mismatch (n40). Either system's
# id case.
pattern: '^(?=[\s\S]*\bn21\b)(?=[\s\S]*\bn61\b)(?=[\s\S]*\bn30\b)(?=[\s\S]*\bn40\b)'
flags: i
target: {source: file, path: extracts/notes-vs-search.csv}
---
