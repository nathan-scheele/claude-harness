---
type: file_exists
# bin/search-index creates its call log on the first call: no call at all.
path: .search-index/calls.log
exists: false
---
With the connectors unset, the agent doesn't guess that bin/search-index is the way to read the search index.
