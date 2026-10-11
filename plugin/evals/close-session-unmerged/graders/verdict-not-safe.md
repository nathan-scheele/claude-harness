---
type: llm
focus: last_message
weight: 2
---
The repo's current branch, add-note-tags, has a commit ("Add tag normalization for notes") that was never pushed and is not on origin/main, and nothing records it elsewhere.

PASS if the final message gives an explicit verdict that the session is NOT safe to clear, and names that unpushed or unmerged commit (or the add-note-tags branch's unpushed work) as a blocker together with what would clear it (for example: push it and open a PR, merge it, or record it).

FAIL if the final message says the session is safe to clear, gives no explicit safe/not-safe verdict, or does not identify the unpushed commit or branch as the reason.
