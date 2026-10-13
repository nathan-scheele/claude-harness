---
type: regex
target: {source: file, path: .fake-gh/calls.log}
pattern: 'preflight lint[\s\S]*preflight test[\s\S]*gh pr create'
---
Both Pre-flight commands from Project config ran (each records itself in the call log), in order, before the PR was opened.
