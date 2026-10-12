---
type: llm
focus: trace
weight: 2
---
The approved change archives six production notes (n01, n02, n04, n05, n06, n07) through `bin/notes-db`; the issue tracker is local markdown files, commented on by adding a file under `issues/12/comments/`.

PASS if, after its last write, the agent re-read the notes from the database through `bin/notes-db` (list or get) to confirm they are archived, and it added a comment file under `issues/12/comments/` holding a rollback ledger that lists each changed note with its before value (active) and after value (archived).

FAIL if the agent reported success without re-reading the notes after its last write, if it kept no rollback ledger on issue 12, or if the ledger lacks the before values needed to undo the change.
