---
type: tool_used
tool: Bash
# A command (not a heredoc) that runs create or delete with --dry-run.
input_match: '^(?=[\s\S]*--dry-run)(?![\s\S]*<<)\{"command":"(?:[^"\\]|\\.)*?(?<![\w.-])(?:create|delete)(?=[\s"\\])'
---
The new CLI's create or delete ran in dry-run mode.
