---
name: audit-and-apply
description: "Audit every consumer against a checklist and fix what's safe: agree scope and checklist, enumerate every consumer into a list file, classify each finding safe / risky / skip with a reason, recommend, apply the safe set through gated-write (data) or one chore PR (code), re-diff the whole scope, and file one issue for the remainder. Use when the operator says audit every X against a checklist or standard and fix what's safe, make every X match Y (copy settings from A to B), or asks which fixes can go in a chore PR."
---

# Audit and apply

Goal: every consumer in scope checked, the safe fixes applied through the right gate and verified, and everything else tracked in one issue. A consumer is one thing the checklist applies to: a record in a live system, or a file in a repo.

"Audit and fix what's safe" is a request to start the work. It is not a go-ahead for the Live writes inside it (S1, ADR 0008). Steps 1-4 use only the connector's reads: the write command, its dry run included, first runs inside gated-write, after the operator's go-ahead.

Load `harness:standards` first (Skill tool) and follow it throughout, especially S1 Live-write gate, S2 pre-authorized checks, S3 live system is truth, S4 structured decisions, S5 deep links, S7 scope discipline and S12 nothing left loose. If it isn't available, carry on with the steps below.

## 1. Read Project config

Read `docs/agents/harness.md` by heading and key:

- `## Data connectors`: the connector for the system holding the consumers (data audits).
- `## Dev and sandbox`: targets where writes are pre-authorized.
- `## Code host` and `## Pre-flight`: for a chore PR (code audits).
- `## Issues`: **Tracker**, for the findings comment and the remainder issue.

A missing file or section, or an `unset` value you need, means stop and point the operator at `/harness:setup-harness`.

## 2. Agree scope and checklist

Settle three things before reading anything in bulk:

- **Scope**: which consumers (every X, in which system or repo, with which exclusions) and which target (live, or a target under `## Dev and sandbox`).
- **Checklist**: numbered checks, each with the value a passing consumer has. A file or issue the operator names is the checklist. For parity ("make B match A", "copy settings from A to B"), the checklist is A's values, one check per key.
- **Audit issue**: the one the operator named, else the one the current branch or PR links.

If the operator gave all three plainly, restate them in one line and carry on (S7). If any is missing or vague (which consumers, what counts as passing), ask (S4) and stop. Every check comes from the checklist; add none of your own.

Then pick the **apply path**:

- **Data**: the consumers are records reached through a `## Data connectors` connector. The safe set goes through `harness:gated-write`.
- **Code**: the consumers are files in a repo. The safe set goes in one chore PR, following [chore-pr.md](chore-pr.md).

If the scope spans both, each part takes its own path, with one list file, one findings table and one remainder issue.

## 3. Enumerate every consumer

Read every consumer in scope, read-only (S2): data from the live system through the connector (S3), code from the default branch. Read the whole scope unfiltered and filter locally, because a deviant consumer is exactly the one a filter misses (a status filter of `active` skips `Active`). With more than about 50 records, delegate the sweep to the `harness:data-digest` subagent with the list file as its extract path. For code, find consumers by search (`git grep`, globs), including ones reached indirectly (a shared partial, a generated file).

Write the **list file**, `.audit/<slug>/consumers.tsv` at the repo root: a header row, then one row per consumer, its key (record id or path) first, then each field the checklist reads. `<slug>` is a short name for this audit. Keep `.audit/` out of git: if `git check-ignore -q .audit` fails, add `.audit/` to `.git/info/exclude` (if that write is refused, say so in the report). Never write it under `.claude/`.

Done when the list file's row count equals the system's count for the scope; state both.

## 4. Check and classify

Run every check against every consumer. Each failing consumer-and-check pair is a finding. Classify each one:

- **safe**: the checklist alone fixes the value, the fix changes nothing anyone relies on beyond passing the check, and it can be undone through the same connector or a revert (a case fix, a default the checklist names).
- **risky**: the fix needs a person's judgement (which value?), changes what people see or can do, is hard to undo, or has no write command. When torn between safe and risky, it is risky.
- **skip**: the checklist or the operator exempts the consumer (frozen, an excluded class) or it falls outside the scope. An exempt consumer is skip for every check, including ones whose fix looks safe. The reason names the rule.

Write `.audit/<slug>/findings.csv` with columns `key,check,current,expected,class,reason`.

Post the **findings table** to chat and as a comment on the audit issue (S12): counts per class (and the consumers that passed), then one row per finding with the consumer as a deep link (S5), the check, current → expected, the class and the reason. End with your recommendation, normally: apply the safe set now and track the rest in one issue.

## 5. Apply the safe set

Apply safe findings only; risky and skip findings are never written. The findings table and recommendation come from reads alone; leave the dry run to gated-write, which runs it after approval.

**Data**: invoke `harness:gated-write` (Skill tool) and hand it the target, the safe set as its scope (each record's key and before → after value), the exact write command, the audit issue, and the operator's advance go-ahead in their words if they gave one. gated-write owns the gate from there: its change table, approval, dry run, canary, spot-check, full run, re-check and ledger, and its dev and sandbox skip.

- An **advance go-ahead** counts when the operator gave it in this conversation, named this write (for example "status case fixes for the safe set"), accepted its effect and stated any condition. Check the classified safe set against that condition. If the safe set holds anything the condition doesn't cover, stop and ask (S1, S4).
- When gated-write stops for the operator's approval, the audit stops too. The last message holds the findings table, your recommendation and gated-write's numbered options. Continue from here once the operator answers. If they decline, the safe set joins the remainder.

**Code**: follow [chore-pr.md](chore-pr.md).

## 6. Re-diff

After the last write, or the chore PR's last commit, run steps 3 and 4 again over the whole scope, not only the consumers you changed: re-read data from the live system, code from the PR branch. gated-write's re-check covers only what it wrote. This pass covers everything else too.

Compare the new results with the findings table:

- **matched**: each applied safe finding now passes, and every other consumer is as it was.
- **unmatched**: a safe fix that didn't take, a risky or skip consumer that changed, or a new finding that wasn't in the table.

Report matched and unmatched counts, with a deep link to each unmatched consumer.

## 7. File one issue for the remainder

File one new issue in the Project config tracker for every risky and skip finding plus anything unmatched (an issue in the operator's own tracker is pre-authorized, S2). Use one issue for all of them, not one per finding. The issue holds:

- a link to the audit issue as its parent;
- the counts;
- a table: consumer (deep link), check, current → expected, class, reason, and what a person must decide or do.

If nothing remains, file nothing and say so. Then comment on the audit issue with links to the remainder issue and to the ledger or chore PR.

Finish with one short report: consumers checked, findings per class, what was applied and through which gate (ledger or PR link), the re-diff result as matched and unmatched counts, and the remainder issue's link (S5).
