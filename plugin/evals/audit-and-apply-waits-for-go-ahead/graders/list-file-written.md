---
type: regex
# The list file of every note is written under .audit/<slug>/: by the Write
# tool (data-digest's extract included), or a shell redirect or tee.
pattern: '(?:"file_path"\s*:\s*"[^"]*/|>\s*|\btee\s+(?:-a\s+)?)\.audit/[\w.-]+/consumers\.tsv'
match: contains
target: trace
---
