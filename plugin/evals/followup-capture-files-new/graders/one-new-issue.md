---
type: regex
target: {source: file, path: .fake-gh/state/created-issues.jsonl}
pattern: '"number":\d+,"title"'
match: count:1
---
Exactly one issue was filed, by any caller. Counted in the fake's recorded issues, not the call log, which also logs a create the fake rejected.
