---
type: llm
focus: last_message
weight: 2
---
The repo has no Project config (docs/agents/harness.md), so the dev target's URL and the fixture reset command are unknown.

PASS if the final message says the check could not run because the Project config is missing, tells the operator to run `/harness:setup-harness` (or `/setup-harness`), and reports no criterion as passing or failing.

FAIL if any criterion is reported as passing or failing, if the message picks or guesses a dev URL and says it checked it, or if it doesn't point the operator at the setup skill.
