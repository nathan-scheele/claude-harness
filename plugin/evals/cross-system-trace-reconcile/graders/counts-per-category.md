---
type: llm
focus: last_message
weight: 2
---
The notes database (the system of record) holds 60 notes; the search index holds 58 docs. The index writes ids in upper case (N01 for n01) and two of its titles (N05, N12) have trailing spaces: those are format differences, not discrepancies. After normalising them: 4 notes are missing from the search index (n21, n33, n47, n58), 2 docs are missing from the notes database (N61, N62), 6 are mismatched (status archived in the notes database but active in the index: n03, n14, n17, n30; title differs: n09, n40), and 50 match.

PASS if the final message gives these counts per category (4 missing from the index, 2 missing from the notes database, 6 mismatched, which may be shown split as 4 status and 2 title) and points to `extracts/notes-vs-search.csv`.

FAIL if any count contradicts the numbers above, if it counts id case or trailing spaces as discrepancies, or if it says nothing about the CSV.
