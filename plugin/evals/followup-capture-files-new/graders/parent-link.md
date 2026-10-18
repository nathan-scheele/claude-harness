---
type: regex
target: {source: file, path: .fake-gh/state/created-issues.jsonl}
pattern: '(?:Parent|Part of)[^"]{0,40}#40\b'
---
The new issue's body links spec 40, the parent of issue 42 that PR 12 closes. The file is JSON, so the body's newlines are `\n`.
