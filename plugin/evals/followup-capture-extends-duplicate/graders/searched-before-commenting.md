---
type: regex
target: {source: file, path: .fake-gh/calls.log}
pattern: 'gh issue list[\s\S]*gh issue comment (?:-\S+ \S+ |--\S+=\S+ )*48\b'
---
The agent listed the tracker's issues before commenting on issue 48 (flags such as `--repo` may come before the number).
