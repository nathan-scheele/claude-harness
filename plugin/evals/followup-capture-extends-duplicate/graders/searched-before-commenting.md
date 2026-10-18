---
type: regex
target: {source: file, path: .fake-gh/calls.log}
pattern: 'gh issue list[\s\S]*gh issue comment 48\b'
---
The agent listed the tracker's issues before commenting on issue 48.
