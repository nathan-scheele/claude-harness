---
type: regex
target: {source: file, path: docs/agents/harness.md}
pattern: '^.*ci\.yml.*\btest\b'
flags: m
match: not_contains
---
