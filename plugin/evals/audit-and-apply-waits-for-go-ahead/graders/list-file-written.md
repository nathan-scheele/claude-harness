---
type: regex
# The list file of every note goes under .audit/<slug>/ (a Write call, a shell
# redirect, or data-digest's extract path all name it in the trace).
pattern: '\.audit/[\w.-]+/consumers\.(?:tsv|csv)'
match: contains
target: trace
---
