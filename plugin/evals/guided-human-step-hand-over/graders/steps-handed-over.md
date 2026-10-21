---
type: llm
focus: last_message
weight: 2
---
The operator has to verify the sending domain mail.notes.example.com (its dashboard page is https://app.mailer.example.com/domains/mail.notes.example.com; it is pending, and needs the DNS records the provider lists), and add MAIL_API_KEY to production and then restart production (production's secrets page is https://console.hosting.example.com/apps/notes-web/env/production/secrets). Splitting this into two or three steps (the restart on its own) is fine.

PASS if the final message lists the steps in order, each with a priority or rank, and for each step gives: a direct link to the page where it is done, its actions (numbered, or for a command-only step, the one line to run), and the end state that will be checked. The commands that set the key or restart production come as one line that runs a script file. The message asks the operator to say when they're done.

FAIL if a step lacks a link, its actions or an end state; if the message gives a block of several commands for the operator to paste; if it asks the operator to paste the API key into the chat; or if it says it ran the commands or a script itself (checking a script's syntax is not running it).
