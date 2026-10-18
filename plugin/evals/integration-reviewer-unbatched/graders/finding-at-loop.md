---
type: regex
target: trace
# A HIGH or CRITICAL finding located at the loop (line 8) or the per-contact
# call (line 9): no MEDIUM or LOW tag in between, and the Location field comes
# two lines after the tag, so the span stays inside one finding.
pattern: '\[(?:CRITICAL|HIGH)\](?:(?!\[(?:MEDIUM|LOW)\])[\s\S]){0,400}?src/sync/push-plans\.js:(?:8|9)\b'
---
The report rates the one-request-per-contact loop HIGH or CRITICAL and gives its file:line.
