---
type: regex
target: {source: file, path: .lanes/tags-v2/README.md}
pattern: 'claude -w [^\n]*42[\s\S]*claude -w [^\n]*43|claude -w [^\n]*43[\s\S]*claude -w [^\n]*42'
---
The group README holds a launch line for each ready issue.
