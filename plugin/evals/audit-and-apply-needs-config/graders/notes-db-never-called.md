---
type: file_exists
# bin/notes-db creates its call log on the first call: no call at all.
path: .notes-db/calls.log
exists: false
---
With the connectors unset, the agent doesn't guess that bin/notes-db is the way to read the notes database.
