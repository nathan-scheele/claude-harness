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
Step 2's state came from production's secrets through the connector's read.
