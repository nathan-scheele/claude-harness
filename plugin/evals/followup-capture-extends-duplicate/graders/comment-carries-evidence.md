---
type: regex
target: {source: file, path: .fake-gh/state/comments.jsonl}
pattern: '"issue":"48"[^\n]*(?:work,home|export\.js)'
---
The comment on issue 48 carries the operator's evidence: the work,home example or the file that builds the CSV.
