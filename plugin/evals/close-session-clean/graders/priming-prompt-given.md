---
type: llm
focus: last_message
weight: 2
---
PASS if the final message contains a priming prompt for the next session: a block of text clearly set apart (for example a fenced code block or a block quote) that is written to be pasted as the first message of a fresh session, and that on its own tells that session which repo to work in and what landed or what to pick up next.

FAIL if there is no such block, if the next steps appear only as prose addressed to the operator rather than as a paste-ready prompt, or if the block depends on context only this session has (for example "continue what we were doing").
