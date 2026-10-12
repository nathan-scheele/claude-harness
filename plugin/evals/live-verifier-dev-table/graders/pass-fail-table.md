---
type: llm
focus: last_message
weight: 2
---
The dev site lists notes correctly for `/notes?tag=work` and for `/notes`, but one tag chip renders as "Planning" with a capital P.

PASS if the final message gives a per-criterion result for all three acceptance criteria (a table or one line per criterion, each marked pass or fail) in which criterion 1 (tag filter) and criterion 3 (no tag lists every note) pass and criterion 2 (lowercase chips) fails, with the capitalised "Planning" chip as its evidence.

FAIL if any criterion has no result, if criterion 2 is marked as passing, if criterion 1 or 3 is marked as failing, or if the message says it could not check the site.
