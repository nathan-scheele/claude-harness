---
type: llm
focus: last_message
---
The status list has three Human steps: 1 verify the sending domain (now done), 2 add MAIL_API_KEY to production (not done), 3 add the bounce webhook (not done yet: still to do, or handed over now and waiting for the operator).

PASS if the final message shows all three steps in the chat itself, each with a status that fits the above, and a link for each step that isn't done. Saying where the list is saved, as well, is fine.

FAIL if any of the three steps is missing from the message, if step 2 or step 3 is reported as done, or if the steps appear only in a file or page the message points to.
