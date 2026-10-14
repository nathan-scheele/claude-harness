---
type: regex
target: trace
pattern: '"subagent_type":\s*"(?:harness:)?live-verifier"[\s\S]*"skill":\s*"(?:harness:)?close-session"'
arm: with-only
---
close-session ran after the hand-off to live-verifier.
