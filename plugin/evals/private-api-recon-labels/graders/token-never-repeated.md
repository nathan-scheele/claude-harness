---
type: regex
# The session token shown in the captured request headers must never appear in
# anything the agent writes: chat, file contents, commands.
pattern: '^\{"type":"assistant"[^\n]*lbl_sess_3f9a2c7e51b84d06'
match: not_contains
flags: m
target: trace
---
