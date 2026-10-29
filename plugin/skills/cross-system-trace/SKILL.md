---
name: cross-system-trace
description: "Trace one failing record hop by hop across systems (source, trigger, sync, target, render) to the first divergence, check sibling records for the same defect, and split the data fix (handed to gated-write) from the code fix (offered as an issue). Reconcile mode bulk-pulls both systems through data-digest and returns counts per category and a CSV with a reason column. Reads only. Use when the operator says X isn't syncing or isn't showing up, A and B disagree, or asks to compare or reconcile two systems."
---

# Cross-system trace

Goal: the operator learns where a value goes wrong between systems, how many records it hits, and which fix to make now and which later.

Load `harness:standards` first (Skill tool) and follow it throughout, especially S2 pre-authorized checks, S3 live system is truth, S4 structured decisions, S5 deep links and S7 scope discipline. If it isn't available, carry on with the steps below.

**Reads only.** Every action you take on a system is a read. Repairs belong to other procedures: a data fix goes to `harness:gated-write` on the operator's go-ahead (step 6), and a code fix is offered as an issue (step 7). That rules out writes, dry runs, re-running a sync, and "touching" a record to make it sync again, on every system: each changes live data or reaches a write path (S1).

**Two modes.** A trace follows one failing example; it is the default. Reconcile compares two systems in bulk: use it when the operator wants every difference counted ("reconcile A and B", "how many are off", "give me a CSV of what doesn't match") rather than one record explained. For reconcile, do step 1 and then follow [reconcile.md](reconcile.md) instead of steps 2-7. A trace whose sibling check (step 5) turns into a sweep can use reconcile.md for that sweep.

## 1. Read Project config

Read `docs/agents/harness.md` by heading and key:

- `## Data connectors`: how to read each system (CLI or MCP server), its access, and its `reads:`.
- `## Dev and sandbox`: targets where a data fix would be pre-authorized; anything else is live.
- `## Issues`: **Tracker**, for step 7.

If the file is missing, or `## Data connectors` or `## Dev and sandbox` is missing or `unset`, stop and tell the operator to run `/harness:setup-harness`. Never guess a command, server or ID. If `## Data connectors` is `none`, a trace still works from code, logs, exports and Human steps (below); reconcile needs a connector or an export per side, so ask the operator for exports or stop.

Read a system only through its connector: any command or tool of a read-only one, only the listed `reads:` of a read-write one, and a CLI exactly as the line spells it, from the repo root. A system on the path with no connector (or none that reads what you need) is still a hop: read it from the code, logs or local exports, or hand the operator a Human step (what to look at, a deep link, what to send back), and mark it in the hop table as read by the operator or not read.

## 2. Pin one failing example

Settle one concrete record before reading anything else: its key in each system, the field, the value the operator expected, the value they saw, where they saw it and roughly when it changed. If the operator gave only a general complaint, ask for one example (S4), or take one from the system of record that should show the problem and say which you chose.

Done when you have one record key, one field, and expected versus observed.

## 3. Map the hops

List every hop the value passes through, in order. The usual five, though a pipeline can have more (a queue, a cache, a transform step):

- **source**: the system of record, where the value is authored;
- **trigger**: what starts propagation (a schedule, a webhook, an event, a manual run);
- **sync**: the code or job that copies and transforms the value;
- **target**: the system holding the copy;
- **render**: where the operator saw it (a page, a report, an email).

Find them without platform knowledge, from:

- the operator's words: which systems, where they saw the value;
- code search: whatever writes the field to the target (sync), schedules or calls that writer (trigger), and reads the field for display (render). Search for the field name, the target's client or CLI, and the job's name;
- `## Data connectors`: which hops you can read, and how;
- the repo's README and docs, for which system is the system of record.

Then settle the key and normalisation (**Key and normalisation** below). The expected value comes from the system of record, never from a mirror or memory (S3).

Done when every hop has a location (system, or `file:line`) and a way to read it there: a connector read, the code path, run evidence, or the operator.

## 4. Compare upstream-first

Read the example at each hop, starting at the source and moving downstream (S2: run the reads yourself). At a data hop the value is what the system holds. At a code hop (trigger, sync, render) it is what that code does with the value from the hop before: read the code path this record takes (filters, mappings, conditions) and any run evidence a connector or log exposes (last run, status, errors).

The **first divergence** is the first hop whose value stops matching the expected one while the hop before it still matched. Downstream of it, check only that each later hop carries the wrong value faithfully (render shows what the target holds), so you know there is one defect and not two.

Done when you can fill this table, with a deep link or `file:line` for each hop (S5):

| Hop | Where | Value for <record> | Matches |
| --- | --- | --- | --- |

and name the first divergence and its cause in one line.

## 5. Check siblings

Do other records share the defect? Derive the sibling set from the cause (every record the faulty filter skips, every record changed after the job broke, every record with the same mapping) and compare those records in both systems.

- A few records: read them through the connectors yourself.
- More than about 20, or a whole system: delegate to data-digest as in [reconcile.md](reconcile.md), scoped to the sibling set.

Done when you have the number of affected records, counted rather than estimated (or `PARTIAL` with a bound), and their keys (up to 10, else the count and an extract path).

## 6. Split the fixes

Two fixes, kept apart so an urgent repair isn't blocked on a code change:

- **Fix the data now**: the records to correct, in which system, from what value to what value (usually the system of record's value copied to the target), and the command or tool that would do it if a connector shows one. It is a Live write unless the target is listed under `## Dev and sandbox`: it runs only through `/harness:gated-write`, after the operator's go-ahead, and not in this skill. Say whether the repair holds before the code is fixed (would the next sync overwrite it, would new records break the same way).
- **Fix the code**: the change that stops new divergences, with `file:line`.

## 7. Offer to file the code fix

Look for an existing open issue in the **Tracker** first (search for the file, job or symptom). Then put the next step to the operator as one structured decision (S4: the question tool, or numbered options with the recommended one first): run the data fix through gated-write, file the code fix (with a draft title and a two-to-three line body: the divergent hop, the cause at `file:line`, the affected count, the example record), both, or neither. File only on a yes, in that tracker, and link the new issue. If **Tracker** is missing or `unset`, give the draft for the operator to file.

## Key and normalisation

Both modes settle these before comparing any value:

- **System of record**: where the value is authored (the README, docs or the sync's direction say which). Where two systems disagree, it is right unless the operator says otherwise.
- **Key**: how a record is identified on each side: the same ID, a mapped external ID, a prefix, a different case.
- **Normalisation**: differences that don't count, applied to keys and values alike: letter case, surrounding whitespace, ID formats (prefixes, zero-padding, numeric versus string IDs), number, date and time zone formats. A record that differs only by these matches.

## Report

One short message (S11):

1. The first divergence: hop, cause, `file:line` or system.
2. The hop table.
3. Siblings: count and keys.
4. The two fixes, the data fix marked as waiting for the operator's go-ahead.
5. The decision from step 7.
