---
type: llm
focus: last_message
weight: 2
---
The repo is on GitHub as example-org/notes-api with default branch main, a CI workflow `ci.yml` with jobs `lint` and `test`, a `deploy.yml` workflow, and `lint`, `typecheck` and `test` package scripts.

PASS if the agent's final message presents all of these as values it found in the repo: the GitHub repo example-org/notes-api, default branch main, the `ci.yml` workflow with jobs `lint` and `test`, and pre-flight commands that run the lint, typecheck and test scripts; and it does not ask the operator to supply any of them (asking the operator to confirm them, or to confirm a full preview, is fine).

FAIL if any of these values is missing or wrong, or if the agent asks the operator what the repo slug, default branch, CI jobs or pre-flight commands are.
