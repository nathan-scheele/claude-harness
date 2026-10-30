---
type: regex
target: {source: file, path: .fake-gh/state/created-issues.jsonl}
pattern: '(?:updateNoteTags|notes-store)[\s\S]*[Aa]cceptance criteria|[Aa]cceptance criteria[\s\S]*(?:updateNoteTags|notes-store)'
---
The new issue names where the defect is (updateNoteTags or lib/notes-store.js) and has acceptance criteria.
