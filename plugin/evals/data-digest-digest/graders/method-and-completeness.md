---
type: regex
target: trace
# data-digest's report as it reaches the main session (the Agent tool result):
# Status complete, then a Method section that names the exact connector
# command. Spans are bounded so the match stays inside one report.
pattern: 'Status:\**\s*complete\b[\s\S]{0,1500}?Method:[\s\S]{0,2500}?bin/notes-db\s+(?:--env\s+production\s+)?list'
---
data-digest's report follows its contract: it says the sweep is complete and gives the exact `bin/notes-db` command under Method.
