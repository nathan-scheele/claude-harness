---
type: regex
target: last_message
pattern: '\.human-steps/[^\s"''`)]+\.sh'
match: contains
---
The final message hands the operator the script by its path, as a one-line invocation.
