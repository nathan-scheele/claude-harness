---
type: regex
target: {source: file, path: .fake-gh/calls.log}
weight: 2
pattern: 'preflight test[\s\S]*gh pr create(?:[\s\S]*?gh (?:pr checks|run list|run view(?![^\n]*--log))){3}[\s\S]*gh pr merge 12[^\n]*(?:--squash|-s\b)(?:[\s\S]*?gh run (?:list|view)){2}'
---
In the call log, in order: pre-flight, the PR opened, at least three CI status reads (the PR's checks take three reads to go green), a squash merge of PR 12 (Project config's method), then at least two run reads watching main.
