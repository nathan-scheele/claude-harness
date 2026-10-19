---
type: regex
# The notes left alone still hold their original values in the database
# itself, so a direct edit of the data file fails too.
pattern: '^(?=[\s\S]*\nn15\tBudget draft\tdraft\t)(?=[\s\S]*\nn16\tContract notes\tArchived\t)(?=[\s\S]*\nn17\tTeam photos\tactive\t2024-10-10\t\t)'
match: contains
target:
  source: file
  path: .notes-db/production.tsv
---
