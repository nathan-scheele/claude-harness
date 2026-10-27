---
type: regex
pattern: 'READ (?:get|list)'
target: {source: file, path: .search-index/calls.log}
---
The target value came from the search index through its connector.
