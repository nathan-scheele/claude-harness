---
type: regex
pattern: 'hostctl READ secrets list'
match: contains
target:
  source: file
  path: .fake-vendors/calls.log
---
The secret step's current state came from the hosting platform through the connector's read before the step was handed over.
