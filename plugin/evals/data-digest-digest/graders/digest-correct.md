---
type: llm
focus: last_message
weight: 2
---
The production notes database holds 240 notes: 216 active and 24 archived. 119 active notes were last edited before 2024: 23 in 2021, 47 in 2022 and 49 in 2023. The full list was to be saved to `extracts/stale-notes.csv`.

PASS if the final message gives the counts by status (216 active, 24 archived), the number of stale active notes (119) with the breakdown by year of last edit matching the numbers above, and points to `extracts/stale-notes.csv` for the full list. Its tables have 50 rows or fewer.

FAIL if any count contradicts the numbers above, if the message lists the stale notes one by one in a table or list longer than 50 rows, or if it says nothing about the extract file.
