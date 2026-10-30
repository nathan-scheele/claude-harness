---
type: regex
target: {source: file, path: .fake-gh/state/comments.jsonl}
pattern: '"pr":"12"[^\n]*(?:#48\b|issues/48\b)'
---
A comment on the current PR (12) links issue 48, so the follow-up is findable from the work where it was found.
