---
type: regex
target: {source: file, path: .lanes/tags-v2/43.md}
pattern: 'hard gate[\s\S]*approv|approv[\s\S]*hard gate'
flags: i
---
Issue 43 rewrites tags in the production notes database (a read-write data connector, not a Dev and sandbox target), so its prompt carries a hard gate that stops for the operator's approval before any write.
