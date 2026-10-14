---
type: llm
focus: last_message
weight: 2
---
PASS if the final message asks the operator to confirm the shown config, or correct it, before it is written (for example options like "Write it" / "Change something", or "Should I write this?").

FAIL if it ends without asking, or says the file was already written.
