---
type: llm
focus: trace
weight: 2
---
The storage backend (SQLite vs managed Postgres) is the operator's decision.

PASS if the agent put that decision to the operator as discrete options, either through an AskUserQuestion call or as a numbered list of options in its final message, where exactly one option is marked as recommended, the recommended option is listed first, and the agent stopped for the answer without choosing a backend itself.

FAIL if the options are only described in prose or a comparison table without a numbered option list or AskUserQuestion call, if the recommendation is conditional ("if X pick A, if Y pick B") or missing, if the recommended option is not listed first, or if the agent picked a backend and carried on without asking.
