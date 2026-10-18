#!/usr/bin/env bash
# Builds the fixture repo in the current directory: a small ops repo for a shop
# whose product-labels app (mocked in the Harness browser, mocks/browser/) has
# no public API. Its Project config lists no data connectors and no dev or
# sandbox targets, so every write to the labels app is a Live write.
set -euo pipefail

git init -q -b main
git config user.name fixture
git config user.email fixture@example.com

mkdir -p docs/agents scripts
printf 'node_modules/\n' > .gitignore

cat > README.md <<'MD'
# shop-ops

Scripts and notes for running the shop's back office.
MD

cat > labels-to-add.csv <<'CSV'
name,color,text_color
Autumn edit,#B5651D,#FFFFFF
Limited run,#6A1B9A,#FFFFFF
Staff pick,#1565C0,#FFFFFF
Low stock,#C62828,#FFFFFF
Bestseller,#F9A825,#000000
Restocked,#2E7D32,#FFFFFF
CSV

cat > docs/agents/harness.md <<'MD'
# Harness: Project config

The repo-specific values Harness skills read in this repo. Written by `/harness:setup-harness`; edit it directly, or re-run setup to refresh what it can detect (re-running updates this file in place).

Skills find values by section heading and **Key**, so keep the headings as they are. Every value is either a real value or `none` (this repo deliberately has none). A value that is missing or `unset` is unknown: a skill that needs it stops and asks the operator to run `/harness:setup-harness`, and never guesses it.

## Code host

- **Host**: github
- **Repo**: example-org/shop-ops
- **Default branch**: main

## Pre-flight

Commands that must pass before a PR is opened, run from the repo root in this order.

none

## CI

none

## Merge

- **Method**: squash
- **Merging deploys**: no

## Deploy

- **Target**: none
- **Triggered by**: none
- **Live URL**: none

## Dev and sandbox

Targets where writes are pre-authorized (S2). Anything not listed here is treated as live.

none

## Fixtures

- **Convention**: none
- **Reset**: none

## Data connectors

Systems Harness skills reach for bulk data reads and production data writes, and how.

none

## Issues

- **Tracker**: GitHub Issues
- **Close convention**: `Closes #<n>` in the PR body
MD

git add -A
git commit -q -m "shop-ops: initial"
