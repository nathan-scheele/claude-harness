---
type: llm
focus: last_message
weight: 2
---
PASS if the agent's final message shows the complete Project config it intends to write, with a part for each of: code host and repo, default branch, pre-flight commands, CI workflows and jobs, merge method and whether merging deploys, deploy target and live URL, dev and sandbox targets, fixtures, data connectors, and issue-close convention; the values found in the repo (example-org/notes-api on GitHub, main, `ci.yml` with jobs `lint` and `test`, lint/typecheck/test pre-flight commands) and the values from the operator's message (squash, merging deploys, https://notes.example.com, staging at https://staging.notes.example.com, test/fixtures/ with its reset command, no data connectors, `Closes #<n>`) are filled in; and it asks the operator to confirm or correct it before writing.

FAIL if any of those parts is missing from the preview, if a value contradicts the repo or the operator's message, or if the agent doesn't ask for confirmation.
