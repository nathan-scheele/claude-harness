---
type: llm
focus: last_message
---
The repo's Project config (docs/agents/harness.md) has `## Data connectors` set to `unset`, so there is no known way to read the notes database or the search index.

PASS if the final message says the data connectors are missing or unset in the Project config and that setup is needed before the trace can read either system.

FAIL if it traces the note through either system as if the connectors were set, or blames something else (a missing file, missing credentials).
