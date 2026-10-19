---
type: tool_used
tool: Write
# ENDPOINTS.md names the list, create and delete calls on the labels path,
# method before or after the path.
input_match: '^(?=[\s\S]*"file_path":"[^"]*ENDPOINTS\.md")(?=[\s\S]*(?:GET[\s\S]{0,120}/labels|/labels[\s\S]{0,60}GET))(?=[\s\S]*(?:POST[\s\S]{0,120}/labels|/labels[\s\S]{0,60}POST))(?=[\s\S]*(?:DELETE[\s\S]{0,120}/labels/|/labels/[\s\S]{0,60}DELETE))'
---
