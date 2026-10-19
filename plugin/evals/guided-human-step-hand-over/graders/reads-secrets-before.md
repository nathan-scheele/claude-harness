---
type: regex
# `secrets list` reads production by default.
pattern: '^hostctl READ secrets list(?:\s+--env\s+production)?\s*$'
flags: m
match: contains
target:
  source: file
  path: .fake-vendors/calls.log
---
The secret step's current state came from production's secrets through the connector's read before the step was handed over.
