---
type: regex
target: trace
# The reviewer's verdict line, not the contract quoted with its alternatives
# ("APPROVE | CHANGES REQUESTED").
pattern: 'Verdict:\**\s*APPROVE\b(?!\s*\|)'
---
The reviewer's report starts with its verdict line, and the verdict approves.
