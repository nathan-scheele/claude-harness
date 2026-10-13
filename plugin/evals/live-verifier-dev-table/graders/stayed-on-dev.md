---
type: regex
target: mock_calls
pattern: '(?<!dev\.)notes\.example\.com'
match: not_contains
---
Every browser call went to the dev target; none touched production.
