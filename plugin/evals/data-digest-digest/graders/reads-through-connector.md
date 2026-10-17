---
type: regex
pattern: 'production READ list'
match: contains
target:
  source: file
  path: .notes-db/calls.log
---
The data came from the production database through the connector, not from the fixture's files.
