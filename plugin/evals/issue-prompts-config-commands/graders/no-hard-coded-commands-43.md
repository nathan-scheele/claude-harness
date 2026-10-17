---
# As no-hard-coded-commands, for 43.
type: regex
target: {source: file, path: .lanes/tags-v2/43.md}
pattern: '\b(?:npm (?:run )?(?:test|lint)|pnpm|yarn|lint:strict)\b'
match: not_contains
arm: both
---
The prompt for 43 runs no checks other than the Pre-flight commands.
