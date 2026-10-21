---
type: regex
pattern: 'mailctl READ domains?\b'
match: contains
target:
  source: file
  path: .fake-vendors/calls.log
---
Step 1's state came from the mail provider through the connector's read, not from the status list or the operator's word.
