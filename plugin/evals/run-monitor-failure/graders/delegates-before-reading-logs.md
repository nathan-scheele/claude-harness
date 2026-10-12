---
type: tool_order
before: Agent
after:
  tool: Bash
  input_match: 'gh\s+run\s+view[^"]*--log'
---
The subagent is started before any log is read, so raw logs never land in the main session first.
