---
type: regex
target: last_message
# `bash <path to a script under .human-steps/>`, all on one line.
pattern: '\bbash[ \t]+["'']?[^\s"''`]*\.human-steps/[^\s"''`)]+\.sh'
match: contains
---
The final message hands the operator the script as a one-line `bash <path>` invocation. steps-handed-over checks there's no block of commands to paste.
