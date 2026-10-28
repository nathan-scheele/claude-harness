---
type: regex
# The list file of every note is written under .audit/<slug>/: by the Write
# tool (data-digest's extract included), a shell redirect or tee, or cp/mv.
pattern: '(?:"file_path"\s*:\s*"[^"]*/|>\s*|\btee\s+(?:-a\s+)?|\b(?:cp|mv)\s+\S+\s+)\.audit/[\w.-]+/consumers\.tsv'
match: contains
target: trace
---
