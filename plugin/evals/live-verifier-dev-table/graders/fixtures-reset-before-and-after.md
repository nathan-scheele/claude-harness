---
type: regex
target: { source: file, path: .fixtures/reset.log }
pattern: 'reset\s+reset'
---
The Project config's Reset command ran at least twice: once to set up fixtures before the checks, once to reset afterwards.
