---
# The fixture's package.json scripts (npm run lint, npm test) and other
# stacks' commands (the private original hard-coded pnpm ones) are not this
# repo's Pre-flight; only Project config says what a Lane runs.
type: regex
target: {source: file, path: .lanes/tags-v2/42.md}
pattern: '\b(?:npm (?:run )?(?:test|lint)|pnpm|yarn|lint:strict)\b'
match: not_contains
arm: both
---
The prompt for 42 runs no checks other than the Pre-flight commands.
