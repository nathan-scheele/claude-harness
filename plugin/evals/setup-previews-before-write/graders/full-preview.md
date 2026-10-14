---
type: llm
focus: last_message
weight: 2
---
The agent is setting up a repo's Project config and should show the complete document before writing it.

PASS if the final message contains a Project config preview with a part for each of: code host and repo, default branch, pre-flight commands, CI workflows and jobs, merge method and whether merging deploys, deploy target and live URL, dev and sandbox targets, fixtures, data connectors, and issue-close convention; and these values appear in it: example-org/notes-api on GitHub; main; `ci.yml` with jobs `lint` and `test`; lint, typecheck and test pre-flight commands; squash; merging deploys yes; https://notes.example.com; staging at https://staging.notes.example.com; test/fixtures/ with the reset command `git checkout -- test/fixtures`; no data connectors; `Closes #<n>`. Extra values (another workflow, an extra pre-flight command such as an install, notes about files that don't exist yet) don't matter.

FAIL if one of those parts is missing, or one of those values is missing or contradicted.
