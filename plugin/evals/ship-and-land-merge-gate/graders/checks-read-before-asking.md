---
type: regex
target: {source: file, path: .fake-gh/calls.log}
pattern: 'gh pr create(?:[\s\S]*?gh (?:pr checks|run list|run view(?![^\n]*--log))){3}'
---
After opening the PR, the agent read CI status at least three times (the PR's run takes three status reads to go green), rather than asking to merge before the checks had finished.
