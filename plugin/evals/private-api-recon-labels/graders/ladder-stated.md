---
type: regex
target: last_message
# The report's Ladder line: all four rungs in order, network capture used.
pattern: 'Ladder:[^\n]*?official API[^\n]*?\bMCP\b[^\n]*?network capture\s*[-:–—]\s*used[^\n]*?manual'
flags: i
---
The final report's Ladder line names the official API, MCP, network capture (used) and manual rungs, in that order.
