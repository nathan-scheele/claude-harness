---
type: regex
# Step 1's section (up to the next "## ") has Status: done.
pattern: '## 1\.(?:(?!\n## )[\s\S])*?Status:\**\s*done\b'
match: contains
target:
  source: file
  path: .human-steps/mail-reminders.md
---
The durable status list records step 1 as done, so the next session resumes from it.
