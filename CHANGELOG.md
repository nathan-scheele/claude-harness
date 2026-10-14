# Changelog

Newest first. The plugin's version lives in `plugin/.claude-plugin/plugin.json`; `scripts/release-check.sh` fails unless it is the newest entry here.

## 0.1.0 - 2026-10-13

The daily delivery loop.

- `harness:setup-harness`: writes the repo's Project config (`docs/agents/harness.md`), detecting what it can and asking only for the rest.
- `harness:ship-and-land`: committed branch to verified production on "ship it": pre-flight checks, PR, CI diagnosis, a stop for your go-ahead before a merge that deploys, CI and deploy monitoring, live verification, close-out.
- `harness:gated-write`: the Live-write procedure for production data writes (fact pass, change table, approval, dry run, canary, full run, re-check, rollback ledger).
- `harness:run-monitor`: watches a CI run, deploy or long job with interval status, checks the outcome against what was expected, and has a subagent find the first failing step.
- `harness:close-session`: checks work is landed or recorded, stops what the session started, removes its worktree, and gives a safe-to-clear verdict and a priming prompt.
- `harness:live-verifier` subagent: checks a change on a dev or live target against acceptance criteria and returns a pass/fail table. Read-only by construction (no edit tools; a hook limits its Bash to reads).
- The Harness browser: chrome-devtools-mcp 1.10.1 with a dedicated, persistent profile in the plugin's data directory.
- Hooks: live-verifier's read-only Bash allowlist, and Harness browser pages forced to open in the background.

Upgrading: see [Upgrade notes](README.md#upgrade-notes) (rename `CONTEXT.md` to `GLOSSARY.md` for the current Base layer).

## 0.0.1

Walking skeleton (untagged): the installable plugin, the Standards skill, and CI with strict validation and the leak check.
