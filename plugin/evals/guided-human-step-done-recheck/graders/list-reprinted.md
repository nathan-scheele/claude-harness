---
type: llm
focus: last_message
---
The status list has three Human steps: 1 verify the sending domain (now done), 2 add MAIL_API_KEY to production (not done), 3 add the bounce webhook (not done yet: still to do, or handed over now and waiting for the operator).

PASS if the final message reprints the list in chat with all three steps and a status for each that fits the above, and gives a link for each step that isn't done.

FAIL if any of the three steps is missing from the message, if step 2 or step 3 is reported as done, or if the message points to a file or page for the list instead of showing it.
