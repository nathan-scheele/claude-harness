---
type: llm
focus: last_message
weight: 2
---
The operator said they did two steps. A live re-read shows: step 1, the sending domain mail.notes.example.com, changed from pending to verified, so it is done. Step 2 is not done: production's secrets are still DATABASE_URL and SESSION_SECRET, with no MAIL_API_KEY (it was set on dev instead, which the agent may or may not mention).

PASS if the final message reports step 1 as done with the change it saw (pending to verified, or "now verified"), reports step 2 as not done because production still has no MAIL_API_KEY, and tells the operator what to do to finish step 2 (re-run the step's command or script for production, or a link to production's secrets page).

FAIL if step 2 is reported as done or verified, if step 1 is reported as not done, or if the message only repeats what the operator said without saying what the check found.
