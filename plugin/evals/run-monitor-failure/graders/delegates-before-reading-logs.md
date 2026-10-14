---
type: regex
target: trace
pattern: '^(?:(?!"name":\s*"Agent")[\s\S])*?2026-01-01T10:02:\d\d\.\d{7}Z'
match: not_contains
---
No line of the run log reaches the trace before the first Agent call, so raw logs never land in the main session first. It keys on the log's timestamps (fixture-repo.sh), not on the command that read it: a subagent may read the log with any command or tool, or not at all.
