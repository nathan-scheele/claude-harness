---
type: regex
# The remainder issue tracks both risky notes.
pattern: '^(?=[\s\S]*\bn15\b)(?=[\s\S]*\bn17\b)'
match: contains
target:
  source: file
  path: issues/14/issue.md
---
