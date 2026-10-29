---
type: regex
pattern: 'mailctl READ domains?\b'
match: contains
target:
  source: file
  path: .fake-vendors/calls.log
---
The domain step's current state (and its dashboard link) came from the mail provider through the connector's read before the step was handed over, so "done" has a before to compare against.
