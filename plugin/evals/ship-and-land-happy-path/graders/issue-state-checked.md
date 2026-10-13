---
type: regex
target: {source: file, path: .fake-gh/calls.log}
pattern: 'gh pr merge[\s\S]*gh issue (?:view|list|close)'
---
After the merge the agent read issue 11's state (or closed it), rather than assuming the merge closed it.
