# Harness: Project config

The repo-specific values Harness skills read in this repo. Written by `/harness:setup-harness`; edit it directly, or re-run setup to refresh what it can detect (re-running updates this file in place).

Skills find values by section heading and **Key**, so keep the headings as they are. Every value is either a real value or `none` (this repo deliberately has none). A value that is missing or `unset` is unknown: a skill that needs it stops and asks the operator to run `/harness:setup-harness`, and never guesses it.

## Code host

- **Host**: github
- **Repo**: nathan-scheele/claude-harness
- **Default branch**: main

## Pre-flight

Commands that must pass before a PR is opened, run from the repo root in this order.

- `claude plugin validate --strict .`
- `claude plugin validate --strict plugin`
- `scripts/test-leak-check.sh`
- `scripts/leak-check.sh .`
- `scripts/test-release-check.sh`
- `scripts/release-check.sh .`
- `scripts/test-guard.sh`
- `scripts/test-setup-detect.sh`
- `scripts/test-fake-gh.sh`
- `scripts/test-eval-tools.sh`

## CI

Workflows and their job ids, as named in the workflow files.

- `ci.yml` (CI): `validate`, `leak-check`, `release-check`, `guard`, `setup-detect`, `fake-gh`, `eval-tools`

## Merge

- **Method**: squash
- **Merging deploys**: yes

## Deploy

- **Target**: the `harness` plugin marketplace, served from this repo's default branch on GitHub (`claude plugin marketplace add nathan-scheele/claude-harness`)
- **Triggered by**: merge to `main`; there is no deploy workflow, installs pick up `main` on their next plugin update
- **Live URL**: https://github.com/nathan-scheele/claude-harness

## Dev and sandbox

Targets where writes are pre-authorized (S2). Anything not listed here is treated as live.

none

## Fixtures

- **Convention**: each eval case's `scaffold_script` builds a throwaway repo in a temp directory per run; shared builders live in `plugin/evals/fixtures/`, CLI fakes in `plugin/evals/fakes/`
- **Reset**: none (every eval run scaffolds fresh)

## Data connectors

Systems Harness skills reach for bulk data reads and production data writes, and how.

none

## Issues

- **Tracker**: see `docs/agents/issue-tracker.md`
- **Close convention**: `Closes #<n>` in the PR body, closed by GitHub on merge to `main`
