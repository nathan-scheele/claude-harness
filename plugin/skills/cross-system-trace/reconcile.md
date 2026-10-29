# Reconcile mode

Goal: every difference between two systems counted by category, with examples, and one CSV the operator can work through row by row. Reads only, as in the trace: both pulls go through data-digest, which never writes; the CSV is the one file you create.

Raw records stay out of the main session: data-digest absorbs them, and the join runs in the shell and prints counts and a few keys, never rows.

## 1. Settle the comparison

Before pulling anything, write down:

- **The two sides**: the system of record and the mirror, with the key and normalisation as in **Key and normalisation** in SKILL.md. Use the systems' real names in everything the operator reads. If you can't tell the formats yet, have the pulls report them (step 2) and settle normalisation before the join.
- **Scope**: which records (all, or a filter both systems can apply alike, such as the sibling set from a trace).
- **The fields to compare**: only those the operator cares about, plus the key.

If the key or the scope is genuinely ambiguous, ask (S4) rather than pick.

## 2. Pull each side through data-digest

Start two Agent calls with `subagent_type: harness:data-digest` in one message, so the pulls run in parallel, one per side. Each delegation prompt gives:

- **Question**: every record in scope from that system, with the key and the compared fields, and the record count.
- **Scope**: the filter, if any.
- **Extract path**: a new CSV file per side, outside hidden directories (e.g. `extracts/<system>-<date>.csv`; data-digest refuses an existing file), with a header row, the key column first, and the values as the system holds them. Normalising is your job (step 4), so the CSV keeps what each system really says.
- Ask it to note in Caveats the key's format and any oddities it saw (case, whitespace, duplicate keys).

## 3. Parse the two reports

data-digest's report has a fixed shape (`Status` / `Question` / `Method` / `Table(s)` / `Caveats` / `Extract`). Take from each:

- **Status**: both must be `complete` for a full reconcile. On `BLOCKED`, relay its reason and fix (often `/harness:setup-harness` to list a read) and stop. On `PARTIAL`, say the comparison is partial, with its bound, and either re-pull narrower or label every count as a lower bound.
- **Extract**: the path, row count, columns and key. Check that its row count matches the records Method says were returned.
- **Method** and **Caveats**: keep them for the report.

Work from these reports and extracts. Pull again only to fill a gap they name.

## 4. Join in the shell

Normalise both extracts as settled in step 1, then do a full outer join on the key with whatever the machine has (`awk`, `join` after `sort`, `jq`, or a short script in your scratchpad). Print only counts and up to three example keys per category. The categories:

- **missing in <mirror>**: the key is only in the system of record;
- **missing in <system of record>**: the key is only in the mirror;
- **mismatched**: the key is on both sides and a compared field differs after normalisation, counted per field as well;
- **matching**: everything else;
- **duplicate key in <system>**, only if a side holds a key twice.

Check the arithmetic before reporting: each side's record count equals its missing, mismatched, matching and duplicate rows added up. Also count how many records differed only by normalisation, so the report can say what was set aside.

## 5. Write the CSV

One file: at the path the operator gave, else `extracts/<system of record>-vs-<mirror>.csv` (a new file; never overwrite one). Header:

```
key,category,field,<system of record>_value,<mirror>_value,reason
```

- One row per discrepancy; a record with two mismatched fields gets two rows. Matching records and format-only differences are left out.
- Values as each system holds them, before normalisation, so the operator sees the real data. Quote any value containing a comma, quote or newline.
- **reason**: one plain sentence the operator can act on, naming which side holds what and which is right, e.g. `in the orders database, not in the warehouse export`, or `status: archived in the orders database (system of record), active in the warehouse export`.

## 6. Report

One short message (S11). Every number and key in it comes from the join's printed output, word for word: if something looks off while writing, re-run the join with a check for it, and report what it prints rather than a recollection.

- A table of counts per category (and per field for mismatches), with up to three example keys each.
- What normalisation set aside, with counts ("58 ids differ only in case, 2 titles only in trailing spaces; not counted").
- The CSV path and its row count, and both extracts' paths.
- Method: each side's system, command and record count, from the data-digest reports, and the status of each pull.

Then the fixes, as in steps 6 and 7 of the trace: correcting the mirror is a data fix that runs only through `/harness:gated-write` on the operator's go-ahead. If one category has an obvious shared cause (every mismatch is a record changed after a certain date, or one status), say so and offer to trace one example from it to find the code cause.
