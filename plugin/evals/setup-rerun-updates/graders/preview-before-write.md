---
type: llm
focus: trace
---
PASS if, before the agent's Write to docs/agents/harness.md, it showed the operator the updated Project config (the whole document, or at least the CI section with the job `unit-tests`) in a message.

FAIL if the agent wrote the file without first showing the updated config, or never wrote it.
