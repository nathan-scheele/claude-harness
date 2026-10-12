---
name: gated-write
description: "Run a production data change through the Live-write procedure: read-only fact pass, change table posted to chat and the issue, explicit approval, dry run, canary of 1-3 records, operator spot-check, full run with progress, re-check against the source of truth, rollback ledger. Skips the gate for dev and sandbox targets listed in Project config. Use when the operator asks to change, fix, backfill, migrate, archive or delete data in a live system, or says 'dry run first'."
---

# Gated write

Goal: a production data change where nothing is written without the operator's go-ahead, every write is checked against the live system, and every change can be undone.

Load `harness:standards` first (Skill tool) and follow it throughout, especially S1 Live-write gate, S2 pre-authorized checks, S3 live system is truth, S4 structured decisions and S12 nothing left loose. If it isn't available, carry on with the steps below and treat every production write as needing the operator's explicit go-ahead for that specific write.

## 1. Read Project config

Read `docs/agents/harness.md` by heading and key:

- `## Data connectors`: the connector (MCP server or CLI) that reaches the target system, and whether it is read-write.
- `## Dev and sandbox`: the targets where writes are pre-authorized.
- `## Issues`: where the relevant issue lives and how to comment on it.

If the file is missing, a section you need is missing, or a value you need is `unset`, stop and tell the operator to run `/harness:setup-harness`. Never guess a connector. If the only connector for the system is read-only, stop and say so.

## 2. Live or pre-authorized

The target is **pre-authorized** only if it is listed under `## Dev and sandbox`. Anything not listed there is live, and `none` there means every target is live. If you can't tell which listed target the operator means, treat it as live.

**Dev or sandbox target:** skip the gate (S2). Make the change through the connector without asking, re-check it (step 9), and report what changed with counts. No change table, approvals, canary or ledger.

**Live target:** run steps 3-10 in order.

## 3. Fact pass (read-only)

Read every record in scope from the live system through the connector (S2, S3), never from repo state, memory or an earlier summary. Work out:

- **Will change**: each record, its current value and its new value.
- **Won't change**: records in scope that stay as they are (already in the target state, excluded by a rule), with the reason.
- **Counts** for each.

## 4. Change table

Post a change table to chat and to the relevant issue (an issue comment in the operator's own tracker is pre-authorized, S2). The relevant issue is the one the operator named, else the one the current branch or PR links; if there is none, file one in the tracker from `## Issues`. The table has:

- Will change / won't change / total in scope, each with a count and a few record IDs as deep links (S5).
- The field or fields changing, before → after.
- The exact command or mutation the write will use.

## 5. Stop for approval

This is a Live write: stop and ask for the operator's explicit go-ahead (S1), through the question tool or S4's numbered fallback. Run nothing through the connector's write command until it comes: not the canary, and not the dry run either (some connectors' dry runs still reach the write endpoint). An operator asking for "dry run first" is asking for this whole procedure, not approving the dry run.

An approval counts only for the change table it was given for. If the operator's request already approves a change table they quote or link, run the fact pass anyway and proceed only if it matches that table exactly; if anything differs, post the new table and stop.

## 6. Dry run

Run the write in dry-run mode if the connector has one; otherwise build the payloads without sending them. Report the counts (will change, unchanged set) and one sample payload. If the counts differ from the approved change table, stop and say why.

## 7. Canary

Write 1-3 representative records from the will-change set, adding their rows to the rollback ledger (step 10) before writing them. Re-read them from the live system and report each one's before → after with a deep link.

## 8. Spot-check, then full run

Ask the operator to spot-check the canary records and give the go-ahead for the full run (S1, S4), then stop. A go-ahead for the canary is not a go-ahead for the full run. Go straight on only if the operator has already explicitly approved the full run itself, and the canary re-read correctly.

Full run: write the rest of the will-change set, adding ledger rows as you go, and post progress at intervals (done / total, failures) (S6). If a write fails, stop, report what was and wasn't written, and ask (S4).

## 9. Re-check against the source of truth

Re-read every record in scope from the live system (S3). Compare each with its intended value, including the won't-change set. Report matched / mismatched counts with deep links to any mismatch. A write call's success response is not proof that the write applied.

## 10. Rollback ledger

The ledger records every change made, so the operator can undo it. It is a CSV with one row per changed field:

```
record_id,field,before,after,stage,written_at
```

`stage` is `canary` or `full`. Take `before` from the fact pass, and add each record's rows before writing it, so a run that stops halfway can still be undone. Post the ledger as a comment on the relevant issue (S12), with one line saying how to roll back (write each `before` value back through the same connector). Don't put secrets in it.

Finish with one short report: what changed (counts), the re-check result, and links to the issue's change table and ledger comments (S5).
