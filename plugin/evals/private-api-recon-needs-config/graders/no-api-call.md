---
type: regex
# The stand-in curl logs every call: with the connectors unset, nothing at all
# reaches the labels API.
pattern: '\S'
match: not_contains
target:
  source: file
  path: .fake-curl/calls.log
---
It stops before any request to the labels API.
