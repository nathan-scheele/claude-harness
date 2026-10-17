# Harness: Project config

The repo-specific values Harness skills read in this repo. Written by `/harness:setup-harness`; edit it directly, or re-run setup to refresh what it can detect (re-running updates this file in place).

Skills find values by section heading and **Key**, so keep the headings as they are. Every value is either a real value or `none` (this repo deliberately has none). A value that is missing or `unset` is unknown: a skill that needs it stops and asks the operator to run `/harness:setup-harness`, and never guesses it.

## Code host

- **Host**: {github | gitlab | bitbucket | other}
- **Repo**: {owner/name}
- **Default branch**: {branch}

## Pre-flight

Commands that must pass before a PR is opened, run from the repo root in this order.

- `{command}`

## CI

Workflows and their job ids, as named in the workflow files.

- `{workflow file}` ({workflow name}): `{job id}`, `{job id}`

## Merge

- **Method**: {squash | merge | rebase}
- **Merging deploys**: {yes | no}

## Deploy

- **Target**: {where production runs, in plain words}
- **Triggered by**: {what starts a deploy, e.g. `deploy.yml` on push to the default branch}
- **Live URL**: {url}

## Dev and sandbox

Targets where writes are pre-authorized (S2). Anything not listed here is treated as live.

- **{name}**: {url or identifier}; {what it is}

## Fixtures

- **Convention**: {where test fixtures and seed data live, and how tests use them}
- **Reset**: {command or steps that put fixtures back}

## Data connectors

Systems Harness skills reach for bulk data reads and production data writes, and how. An MCP server is named as in its tool names (`mcp__<name>__<tool>`). The read-only subagents (data-digest, live-verifier) may use any command or tool of a read-only connector, but only the `reads:` listed for a read-write one: its read-only subcommands (the words after the command) or tool names.

- **{system}**: {MCP server `name` | CLI `command`}; {read-only | read-write}[; reads: `{subcommand or tool}`, `{subcommand or tool}`]

## Issues

- **Tracker**: {see `docs/agents/issue-tracker.md` when the Base layer set it up, else where issues live}
- **Close convention**: {how an issue gets closed, e.g. `Closes #<n>` in the PR body, closed by GitHub on merge to the default branch}
