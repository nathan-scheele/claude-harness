---
# file_exists sees only files created during the run, so the fixture's own
# harness.md doesn't count; any new file here is a second config.
type: file_exists
path: docs/agents/*
exists: false
---
