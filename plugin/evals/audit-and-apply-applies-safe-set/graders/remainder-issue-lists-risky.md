---
type: regex
# The remainder issue tracks every note left alone (risky n15 and n17, skip
# n16) and links the audit issue.
pattern: '^(?=[\s\S]*\bn15\b)(?=[\s\S]*\bn16\b)(?=[\s\S]*\bn17\b)(?=[\s\S]*(?:#13\b|\bissues?[ /]?13\b|\b13/issue\.md))'
match: contains
target:
  source: file
  path: issues/14/issue.md
---
