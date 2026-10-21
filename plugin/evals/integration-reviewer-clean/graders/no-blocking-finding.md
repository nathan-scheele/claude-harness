---
type: regex
target: trace
pattern: '\[(?:CRITICAL|HIGH)\]'
match: not_contains
---
No HIGH or CRITICAL finding against a change that batches, maps and handles errors as the repo's docs say.
