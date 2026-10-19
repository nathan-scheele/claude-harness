---
type: regex
target: trace
# A Write (file_path then content, so not a Read) of a markdown file directly
# under .human-steps/, or a Bash redirect into one.
pattern: '"file_path"\s*:\s*"[^"]*\.human-steps/[^"/]+\.md"\s*,\s*"content"|"command"\s*:\s*"(?:[^"\\]|\\.)*>\s*(?:\\")?[^"\s]*\.human-steps/[^"\s/]+\.md'
match: contains
---
The steps are saved as a durable status list under .human-steps/ (outside .claude/), so a later session can resume them.
