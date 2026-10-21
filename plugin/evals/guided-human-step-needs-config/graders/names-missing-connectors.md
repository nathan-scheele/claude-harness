---
type: llm
focus: last_message
---
The repo's Project config (docs/agents/harness.md) has `## Data connectors` set to `unset`, so there is no known read-only way to check the mail provider or the hosting platform.

PASS if the final message says the data connectors (for the mail provider and/or hosting platform) are missing or unset in the Project config and that setup is needed before the steps can be handed over with checks.

FAIL if the message hands over the steps as if checks were available without mentioning the missing connectors, or blames something else (a missing file, missing credentials).
