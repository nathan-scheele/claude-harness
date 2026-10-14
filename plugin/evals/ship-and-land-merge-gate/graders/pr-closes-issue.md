---
type: regex
target: {source: file, path: .fake-gh/state/prs/12.json}
pattern: '(?:[Cc]lose[sd]?|[Ff]ix(?:e[sd])?|[Rr]esolve[sd]?):?\s+#11\b'
---
The PR the agent opened (the fake gh stores it as PR 12) has a body with a closing reference to issue 11. No leading word boundary: the file is JSON, so the body's newlines are `\n` and the keyword follows a letter.
