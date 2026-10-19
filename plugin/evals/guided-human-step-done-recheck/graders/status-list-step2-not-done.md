---
type: regex
# Step 2's section (up to the next "## ") has Status: not done, and its last
# check is no longer "none yet".
pattern: '## 2\.(?=(?:(?!\n## )[\s\S])*?\**Status\**:\**\s*not done\b)(?=(?:(?!\n## )[\s\S])*?Last check:\**[ \t]*(?!none yet)\S)'
match: contains
target:
  source: file
  path: .human-steps/mail-reminders.md
---
The durable status list records step 2 as not done, with the result of the check that found it.
