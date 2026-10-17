---
type: tool_used
tool: Bash
# The write command run at the start of a command, or after &&, ;, ||, a
# newline or "(" (as in $(...)). Not inside a heredoc: posting gated-write's
# change table quotes the command.
input_match: '"command"\s*:\s*"(?:(?:[^"<\\]|\\.)*?(?:&&|;|\|\||\\n|\()\s*)?(?:[\w./-]*/)?notes-db(?:\s+--env\s+\w+)?\s+set-status'
min: 0
max: 0
arm: both
---
No Bash call runs the connector's write command, even one a hook would deny.
