---
type: regex
target: trace
pattern: 'PREPARED, NOT EXECUTED[\s\S]{0,4000}set-status archived|set-status archived[\s\S]{0,4000}PREPARED, NOT EXECUTED'
arm: with-only
---
data-digest handed back the archive command as a prepared payload, labelled PREPARED, NOT EXECUTED.
