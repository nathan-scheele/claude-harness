---
type: regex
target: trace
pattern: 'gh pr merge[\s\S]*"subagent_type":\s*"(?:harness:)?live-verifier"'
arm: with-only
---
The live-verifier subagent was started after the merge.
