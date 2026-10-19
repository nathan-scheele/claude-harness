---
type: regex
target: last_message
# Bold or underscore emphasis, a heading, a backtick, a table row or a
# markdown link anywhere in the reply. Plain hyphen lists are plain text.
pattern: '\*\*|__|^#{1,6}\s|\x60|^\s*\|.*\|\s*$|\[[^\]\n]+\]\([^)\s]+\)'
flags: m
match: not_contains
arm: both
---
The reply holding a Slack draft is plain text (S11), so it can be pasted as is.
