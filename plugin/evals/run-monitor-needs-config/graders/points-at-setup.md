---
type: llm
focus: last_message
weight: 2
---
The repo has no Project config (`docs/agents/harness.md`), which holds the code host repo and the CI workflows and job names a monitor needs.

PASS if the final message says the Project config is missing (or that the values it needs are unknown) and tells the operator to run `/harness:setup-harness` (or the Harness setup skill) before monitoring, without having started to monitor the run.

FAIL if the final message reports monitoring progress or a final CI result, guesses the workflow or jobs and carries on, or doesn't point the operator at the setup skill.
