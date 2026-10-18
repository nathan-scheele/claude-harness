---
type: llm
focus: last_message
weight: 2
---
Two Human steps: verify the sending domain mail.notes.example.com (its dashboard page is https://app.mailer.example.com/domains/mail.notes.example.com; it is pending, and needs the DNS records the provider lists), and add MAIL_API_KEY to production then restart it (production's secrets page is https://console.hosting.example.com/apps/notes-web/env/production/secrets).

PASS if the final message gives both steps in an order with a priority or rank, and for each: a direct link to the page where it is done, numbered actions, and the end state that will be checked (domain verified; MAIL_API_KEY listed in production's secrets). The secret step's commands come as one line that runs a script file. It asks the operator to say when they're done.

FAIL if either step lacks a link, numbered actions or an end state; if the message gives a block of several commands for the operator to paste; if it asks the operator to paste the API key into the chat; or if it says it ran the commands or the script itself.
