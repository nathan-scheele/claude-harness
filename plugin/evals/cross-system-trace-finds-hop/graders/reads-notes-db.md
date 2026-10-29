---
type: regex
pattern: 'production READ (?:get|list)'
target: {source: file, path: .notes-db/calls.log}
---
The source value came from the notes database through its connector.
