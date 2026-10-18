---
type: tool_used
tool: Write
# ENDPOINTS.md names the list, create and delete calls on /v2/labels.
input_match: '^(?=[\s\S]*"file_path":"[^"]*ENDPOINTS\.md")(?=[\s\S]*GET[\s\S]{0,120}/v2/labels)(?=[\s\S]*POST[\s\S]{0,120}/v2/labels)(?=[\s\S]*DELETE[\s\S]{0,120}/v2/labels/)'
---
