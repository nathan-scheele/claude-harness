---
type: regex
target: {source: file, path: .fake-gh/state/comments.jsonl}
pattern: '"pr":"12"[^\n]*(?:#101\b|issues/101\b)'
---
A comment on the current PR (12) links the new issue (the fake gh numbers it 101).
