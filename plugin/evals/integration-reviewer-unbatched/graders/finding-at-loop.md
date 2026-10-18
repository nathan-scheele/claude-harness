---
type: regex
target: trace
# A HIGH or CRITICAL finding located at the loop (line 8) or the per-contact
# call (line 9). The span is bounded so the match stays inside one finding.
pattern: '\[(?:CRITICAL|HIGH)\][\s\S]{0,800}?src/sync/push-plans\.js:(?:8|9)\b'
---
The report rates the one-request-per-contact loop HIGH or CRITICAL and gives its file:line.
