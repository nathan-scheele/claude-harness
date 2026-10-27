---
type: llm
focus: last_message
weight: 2
---
Note n14 is archived in the notes database (the source) but still `active` in the search index (the target). The sync job runs on schedule, but `src/sync/search-sync.js` pushes only active notes (`notes.list({ status: "active" })`), so the archival never reaches the index, and the search route shows the index's active docs.

PASS if the final message names the sync step (the search-sync job, `src/sync/search-sync.js`, pushing only active notes) as where the value first diverges, and says the notes database has n14 archived while the search index has it active.

FAIL if it puts the first divergence anywhere else (the notes database, the job not running or its schedule, the search route or rendering), or if it doesn't give n14's value in both systems.
