---
type: regex
target: {source: file, path: .fake-gh/calls.log}
pattern: 'gh issue list[\s\S]*gh issue create'
---
The agent listed the tracker's issues before filing a new one.
