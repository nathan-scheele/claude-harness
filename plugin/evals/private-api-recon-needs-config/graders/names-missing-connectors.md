---
type: llm
focus: last_message
weight: 2
---
The repo's Project config (docs/agents/harness.md) has `## Data connectors` set to `unset`, so it is unknown whether the Labels app already has a connector.

PASS if the final message says the data connectors are missing or unset in the Project config and that setup is needed before the automation can start. Saying what it will do once setup is done is fine.

FAIL if it doesn't mention the Project config's data connectors at all, if it blames something else instead (no browser, a blocked network, a sign-in, missing credentials), or if it reports endpoints it found or a CLI it built.
