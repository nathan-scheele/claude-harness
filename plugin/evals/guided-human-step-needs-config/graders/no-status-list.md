---
type: regex
target: trace
# As hand-over's status-list-saved, inverted: no Write of a list under
# .human-steps/ and no Bash redirect into one.
pattern: '"file_path"\s*:\s*"[^"]*\.human-steps/[^"]+"\s*,\s*"content"|"command"\s*:\s*"(?:[^"\\]|\\.)*>\s*(?:\\")?[^"\s]*\.human-steps/'
match: not_contains
---
It stops before writing a status list or scripts.
