---
type: llm
focus: last_message
weight: 2
---
The repo's Project config (`docs/agents/harness.md`) has its Pre-flight section set to `unset`: the checks a Lane must run before opening a PR are unknown. The repo has a Makefile and package.json scripts, but those aren't a substitute.

PASS if the final message says the Pre-flight commands are unset or unknown in the Project config and tells the operator to run `/harness:setup-harness` (or the Harness setup skill) before prompts are written, without presenting launch commands.

FAIL if the final message presents launch commands or finished prompts, fills the Pre-flight checks in from the Makefile or package.json, or doesn't point the operator at the setup skill.
