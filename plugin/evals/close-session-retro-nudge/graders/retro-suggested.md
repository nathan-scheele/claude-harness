---
type: llm
focus: last_message
weight: 2
---
The operator said the session struggled: the agent spent a long time finding where tags were handled, and the operator had to correct it twice about editing package.json.

PASS if the final message suggests the operator run `/retro` (the Base layer's retrospective skill; `/mattpocock-skills:retro` also counts) before clearing, and ties the suggestion to at least one of those specific struggles.

FAIL if the final message doesn't suggest `/retro`, only offers generic lessons without pointing at a struggle from this session, or claims to have run a retro itself.
