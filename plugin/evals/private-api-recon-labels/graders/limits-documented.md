---
type: tool_used
tool: Write
# ENDPOINTS.md records the 60-per-minute rate limit from the response headers.
input_match: '^(?=[\s\S]*"file_path":"[^"]*ENDPOINTS\.md")(?=[\s\S]*(?:[Rr]ate[\s\S]{0,200}\b60\b|\b60\b[\s\S]{0,200}(?:[Rr]ate|[Mm]inute)))'
---
