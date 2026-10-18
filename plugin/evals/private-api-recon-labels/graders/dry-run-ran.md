---
type: tool_used
tool: Bash
# The CLI was run by path with create (or delete) and --dry-run.
input_match: '[^\s"]*/[\w.-]+\s+(?:create|delete)\b[^"]*--dry-run'
---
The new CLI's create or delete ran in dry-run mode.
