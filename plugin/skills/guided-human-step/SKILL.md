---
name: guided-human-step
description: "Hand the operator the steps only they can do (a sign-in, clicks in a vendor dashboard, a command that needs their credentials) as a prioritised list, each with a deep link, numbered actions and the end state that will be checked; commands go in a script file with a one-line invocation. Saves a status list the operator can resume in a later session. When the operator says done, re-reads live state read-only, reports what actually changed against what was there before, updates the list and reprints it. Never does the step itself. Use when the operator says walk me through it, give me the steps with links, what do I need to do, I did it, done, confirm it, what's left, or when a Harness skill or subagent (live-verifier's WAITING report) hands over Human steps."
---

# Guided Human step

Goal: the operator does each step once, from a link, without hunting or guessing, and "done" means the live system shows it done, not that someone said so. You hand steps over and check them; you never perform them.

Load `harness:standards` first (Skill tool) and follow it throughout, especially S2 pre-authorized checks, S3 live system is truth, S5 deep links, S11 short and plain, S12 nothing left loose and S13 one-line commands. If it isn't available, carry on with the steps below.

**Reads only.** Never run a step's command or script, never sign in, click Save or submit anything for the operator, and never write through a data connector to finish a step, even one that would fail without credentials. Checks are reads (step 3). If the operator asks you to do a step after all, it is no longer a Human step: a write to a dev or sandbox target is pre-authorized (S2), and any other write is a Live write that goes through `harness:gated-write` (S1). The only files you write are the status list and its scripts (step 4).

## 1. Read Project config

Read `docs/agents/harness.md` if it exists and take values by section heading and key:

- `## Data connectors`: each system, the CLI or MCP server that reaches it, whether it is read-only or read-write, and a read-write one's `reads:`. These are the only way to read a vendor system's state (ADR 0003).
- `## Dev and sandbox`: the dev targets; anything else is live.
- `## Deploy`: **Live URL**.

A missing file, or a missing or `unset` value, doesn't stop the hand-over: the operator still needs the steps. It means a step whose check needs that value gets no check (step 3); say which value is missing and that `/harness:setup-harness` adds it.

## 2. Find the list: resume or start

Status lists live in `<main checkout>/.human-steps/<slug>.md`, where the main checkout is the parent of `git rev-parse --path-format=absolute --git-common-dir` (a worktree's folder disappears when its session closes), or in `~/.human-steps/` when that wasn't writable (step 4).

- **Resume** when the operator says done, what's left, or names steps from earlier: read the lists in both places and pick the one that matches what they named. More than one fits and their words don't settle it: ask (S4). None fits: say so and ask what the steps were; never reconstruct a list from memory.
- **Start** otherwise. Take the steps from what the operator gave: their request, a pasted brief, an issue or PR, or another skill's or subagent's Human steps (live-verifier's `Verdict: WAITING` report lists them in the format below).

Before listing a step, check it really is the operator's: if you can do it with a read or a pre-authorized write, do it instead (S2).

**Heavy credential setup** (several secrets to create across vendor dashboards and store in CI or env files): call the Base layer's `wizard` (Skill tool, `mattpocock-skills:wizard`) to build an interactive script for it, and list running that script as one command step. If `wizard` isn't installed, write the steps in this skill's format.

## 3. Write each step

For every step work out, from the live system and current docs (S3), never from memory:

- **Changes**: what the step changes and where.
- **Link**: a deep link to the exact page or record where it's done (S5). Take it from the live system (a connector read's output, the app's own URLs, the Project config) or the vendor's current docs. Never make a URL up: if you can't find the exact page, link the nearest one you can verify and say which page to go to from there.
- **Steps**: numbered actions, one click or entry each, with labels as the page shows them. Never ask for a password, token or key in chat; a secret goes from the vendor's page straight into the command or field that needs it.
- **Command** (command steps only): a script file plus a one-line invocation (S13). Write it to `.human-steps/<slug>/<n>-<short name>.sh`: `#!/usr/bin/env bash`, `set -euo pipefail`, a header comment saying what it changes, `cd` to the repo root if it uses repo paths, and an `echo` of the outcome at the end. Secrets are read from the keyboard (`read -rs`) or the operator's environment, never written into the file. The invocation is one line, `bash <path>`. Don't run it, not even to test it; `bash -n <path>` checks the syntax.
- **End state**: what will be true once it's done, in terms the check can see.
- **Check**: how you will confirm the end state with a read, chosen when the step is written so "done" has something to run:
  - a read through a `## Data connectors` system: any command of a read-only one, or a read-write one's listed `reads:` only;
  - a read-only shell read: `gh` reads, `curl` GET or HEAD, `git` and file reads;
  - a page in the Harness browser, delegated to the Harness `live-verifier` subagent (Agent tool) with the end state as its criterion and the target, when the end state shows only on a page (a sign-in, a dashboard setting with no API);
  - `none` when nothing above can see it. The step can then only end `unchecked`; say so when you hand it over.
- **Before**: run the check now and record what it shows, with the time. That is what "done" is compared against. For a live-verifier check, record what the page showed if this session already saw it, otherwise `not read` (one subagent run per step is too slow just for a before).

Then put the steps in priority order and give each a priority with a short reason: **P1** blocks other steps or something live, **P2** needed for the work in hand, **P3** can wait. A step that depends on another comes after it.

## 4. Save the status list

Write the list to `<main checkout>/.human-steps/<slug>.md`, the slug a short name for what the steps are for (`31-reminder-emails`). If this session can't write there (a worktree-isolated session), use `~/.human-steps/<repo name>-<slug>.md` and say so. Keep both out of `.claude/`: Claude Code guards that folder, so writes there stall on a permission prompt or are refused. If `git check-ignore -q <file>` fails, add `.human-steps/` to the main checkout's `.git/info/exclude` (local to this clone; the tracked `.gitignore` stays as it is) and say so.

The file, one section per step:

```
# Human steps: <what they're for>

For: <issue or PR link, or what the operator asked>
Updated: <YYYY-MM-DD HH:MM>

## 1. <action>
- Status: todo | waiting | done | not done | unchecked
- Priority: P1 | P2 | P3, <reason>
- Changes: <what changes, where>
- Link: <deep link>
- Steps:
  1. <action>
  2. <action>
- Command: `bash <script path>` (command steps only)
- End state: <what will be true>
- Check: <the read, or "none">
- Before: <what the check showed when the step was written> (<YYYY-MM-DD HH:MM>)
- Last check: <YYYY-MM-DD HH:MM>: <what it showed>, or "none yet"
```

Statuses: `todo` not handed over yet; `waiting` handed over, waiting for done; `done` the check shows the end state; `not done` the operator said done but the check doesn't show it; `unchecked` the operator said done and there is no check. Update the file every time a status or check result changes.

## 5. Hand the steps over

In chat, the list first, one line per step in the **Human step format** (below), then each step that can be done now in full: changes, link, numbered steps, the command line, end state. With more than five, give the first five in full and say the rest follow. Mark what you handed over `waiting`. End by asking the operator to say done (or done with which steps) when they've finished.

## 6. On "done": re-check and report the delta

For each step the operator says is done (all `waiting` steps if they don't say which):

1. Run its check again. A read that fails (network, sign-in, a hook's `Blocked:`) is not a result: say so, and keep the step `waiting`.
2. Compare with **Before** and **End state**, and report the delta: `before → now` in the check's own terms (`status pending → verified`).
3. Set its status: `done` if the end state shows; `not done` if it doesn't, with what the check shows instead and the action that's still missing (look for the likely cause with reads, such as the change landing in the wrong place, and hand that step over again); `unchecked` if it has no check, said plainly.

Never set `done` from the operator's word or a page's success message alone. Update the file, then reprint the whole list in chat (not as a file or artifact), and hand over the next steps that can be done now (step 5). When every step is `done` or `unchecked`, say so; the status list and its scripts stay until the operator removes them (`rm -r <main checkout>/.human-steps/<slug>.md <main checkout>/.human-steps/<slug>/`, one line to hand them).

Steps that came from live-verifier's `WAITING` report: once they're done, resume live-verifier with them (its **Resume** input: the steps done and its REMAINING list), so it continues the verification it stopped.

## Human step format

One line per step. live-verifier reports Human steps in this format, and other Harness skills that hand a step to the operator use it too, so any of them can pass their steps here. Keep it stable:

```
N. <what the operator does> - <deep link> - then: <the end state that will be checked>
```

In this skill's chat list, the status and priority go in brackets before the action:

```
1. [done, P1] Verify the sending domain - <link> - then: the domain shows verified
2. [not done, P1] Add the API key to production - <link> - then: production's secrets include the key
3. [todo, P2] Add the bounce webhook - <link> - then: the webhooks list has it
```
