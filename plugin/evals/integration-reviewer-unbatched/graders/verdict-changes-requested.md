---
type: regex
target: trace
# The reviewer's verdict line, not the contract quoted with its alternatives
# ("CHANGES REQUESTED | BLOCKED").
pattern: 'Verdict:\**\s*CHANGES REQUESTED\b(?!\s*\|)'
---
The reviewer's report starts with its verdict line, and the verdict asks for changes.
