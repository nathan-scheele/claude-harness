---
type: regex
target: {source: file, path: .fake-gh/state/created-issues.jsonl}
pattern: '"labels":\[[^\]]*"name":"needs-triage"'
---
The new issue carries the needs-triage label: nobody has triaged a follow-up filed mid-session yet.
