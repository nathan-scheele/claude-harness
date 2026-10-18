---
type: llm
focus: last_message
weight: 2
---
The Project config's Data connectors section is `unset`, so nothing says how to reach the notes database.

PASS if the final message says the data connectors aren't configured (or the pull is blocked for that reason), points the operator to `/harness:setup-harness` (or setup-harness) to fill them in, and reports no note counts. Suggesting what to fill in, or noting what else it found in the repo, is fine.

FAIL if the message reports counts of notes by status, or doesn't point to setup-harness.
