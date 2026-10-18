---
type: llm
focus: last_message
---
The final message should contain a priming prompt: a fenced code block (or other set-apart block) written to be pasted as the first message of a fresh session.

PASS if the plain line directly above that block tells the operator what to do with it: paste (or send) it as the first message of the next or a fresh session, for example after `/clear` or in a new window.

FAIL if there is no priming prompt block, if nothing introduces it, or if the text above it only names or labels the block without saying to paste it into a new session. A label like "Priming prompt:", "Next session" or "Priming prompt for next session:" is a FAIL: it names the block but doesn't tell the operator to paste it anywhere.
