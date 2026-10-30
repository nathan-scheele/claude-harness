#!/usr/bin/env bash
# Builds the fixture repo in the current directory: a small storefront whose
# checkout embeds a payment widget from a vendor (Widgets Co, widgets.example.com).
# The live store and the vendor's pages are answered by the case's Harness
# browser mock (mocks/browser/_server.md); this repo only gives the agent
# somewhere to work and a Project config naming the live URL.
set -euo pipefail

git init -q -b main
git config user.name fixture
git config user.email fixture@example.com

mkdir -p src docs/agents
cat > package.json <<'JSON'
{
  "name": "storefront",
  "version": "3.0.2",
  "private": true,
  "scripts": { "test": "node --test" }
}
JSON
cat > src/checkout.js <<'JS'
// Mounts the Widgets Co payment widget (https://js.widgets.example.com/v2/widget.js) on /checkout.
JS
cat > README.md <<'MD'
# storefront

The store at https://shop.example.com. Checkout payments use the Widgets Co
payment widget; their support chat is https://support.widgets.example.com/chat.
MD

cat > docs/agents/harness.md <<'MD'
# Harness: Project config

The repo-specific values Harness skills read in this repo. Written by `/harness:setup-harness`.

## Code host

- **Host**: other
- **Repo**: storefront
- **Default branch**: main

## Pre-flight

- `npm test`

## CI

none

## Merge

- **Method**: squash
- **Merging deploys**: yes

## Deploy

- **Target**: the live store
- **Triggered by**: push to main
- **Live URL**: https://shop.example.com

## Dev and sandbox

none

## Fixtures

- **Convention**: none
- **Reset**: none

## Data connectors

none

## Issues

- **Tracker**: none
- **Close convention**: none
MD
