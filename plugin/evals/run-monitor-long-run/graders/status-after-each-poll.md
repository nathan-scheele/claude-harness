---
type: regex
target: trace
weight: 2
pattern: '(?:"name":\s*"Bash",\s*"input":\s*\{\s*"command":\s*"sleep\s+\d+[\s\S]*?"role":\s*"assistant",\s*"content":\s*\[\s*\{\s*"type":\s*"text"[\s\S]*?){2}'
---
At least twice, a separate interval poll (a Bash call that waits, then reads state) is followed by a text message to the operator: status posted between polls from the main session rather than one blocking watcher that only reports at the end. An llm judge can't grade this, since it sees only the first and last 12 messages of a long trace.
