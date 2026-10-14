---
type: regex
target: trace
pattern: 'gh pr merge(?:[\s\S]*?gh run (?:list|view)){2}[\s\S]*"subagent_type":\s*"(?:harness:)?live-verifier"'
arm: with-only
---
The live-verifier subagent was started after the merge and after the deploy was watched (at least two run reads), not straight after the merge.
