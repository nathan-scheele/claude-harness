---
name: issue-prompts
description: "Prepare Lanes: for one or more issues, write a self-contained prompt file per issue (spec and ADRs to read, code to reuse, scope, sibling Lanes, approval gates for Live writes, the repo's Pre-flight commands from Project config) plus a README, and reply with one-line commands that start each issue in its own Claude session and worktree. Takes issue numbers, or a label or spec to find the issues that are unblocked now. The separate-session alternative to the Base layer's implement-spec; it doesn't start the sessions. Use when the operator asks to write prompts for issues, prep lanes, or what can run in parallel and give me commands."
---

# Issue prompts

Goal: each Lane starts from one launch line and a prompt that already says what the issue doesn't: what to read, what to reuse, where to stop for approval, and who else is building nearby. The operator runs the launch lines; this skill only prepares them.

Load `harness:standards` first (Skill tool) and follow it, especially S1 Live-write gate, S3 live system is truth, S4 structured decisions, S5 deep links, S7 scope discipline, S12 nothing left loose and S13 one-line commands. If it isn't available, carry on with the steps below.

Args: issue numbers (`12 14`), or a label or a spec issue number, optionally `group=<folder>`.

Every code-host command lives in **GitHub commands** at the end; always pass `--repo <Repo>` from Project config.

## 1. Read Project config

Read `docs/agents/harness.md` and take values by section heading and key:

- `## Code host`: **Host**, **Repo**, **Default branch**.
- `## Pre-flight`: the commands, in order.
- `## Dev and sandbox`: targets where writes are pre-authorized.
- `## Data connectors`: each system, how it's reached, and whether it's read-only or read-write.
- `## Issues`: **Close convention**.

If the file is missing, or any of these is missing or `unset`, stop before writing anything and tell the operator to run `/harness:setup-harness`, naming what's missing. Never fill a gap from `package.json`, a Makefile or CI files: a Lane runs exactly what Project config says. `none` is a real answer (`## Pre-flight` none means the prompt names no checks).

v1 reads issues from GitHub only. If **Host** is anything else, say so and stop.

Also read `docs/agents/triage-labels.md` if it exists: it maps the triage roles (`needs-triage`, `ready-for-human`, …) to this repo's label strings. Without it, use the role names as the labels.

## 2. Pick the issues

- Fetch the default branch from the remote (usually `origin`): `git fetch -q origin <Default branch>`. Every code fact in a prompt comes from `origin/<Default branch>`, not the local checkout.
- **Given numbers**: use them, and still check their blockers.
- **Given a label**: the open issues with that label. **Given a spec**: its open sub-issues. Drop the spec itself, parent issues, and issues labelled with the `ready-for-human` role (list those separately: a Lane can't do them).
- **Blockers come from both places**, because trackers drift: GitHub's native blocked-by links (`blockedBy`, which carries each blocker's state) and every issue in the body's `## Blocked by` list (read each one's state). An issue is **ready** only when every blocker from either source is CLOSED. When the two sources disagree (a body lists a blocker the links don't, or the reverse), name the issue and the gap in the reply and offer to add the missing link or list entry (S4, S12).
- If any issue is blocked, show a ready vs blocked table (issue, blockers still open). Write prompts only for ready issues unless the operator says otherwise.

## 3. Gather context

Done when every ready issue has the facts below, each path and symbol checked. With more than two ready issues, send one Explore agent per issue (Agent tool, in parallel) and ask for exactly these facts back.

- The issue and its comments, its parent spec, and the ADRs and `GLOSSARY.md` sections it names.
- Sibling work already merged: for each closed blocker, `git log origin/<Default branch> --oneline --grep '#<blocker>'`, plus its closing comments (they carry gotchas and the operator's decisions).
- **Code to reuse**: the helpers, modules, scripts and fixtures the issue builds on. Every path or symbol a prompt names must exist on `origin/<Default branch>`: check each with `git cat-file -e origin/<Default branch>:<path>` or `git grep <symbol> origin/<Default branch>`.
- Open PRs touching the same area.
- Earlier prompts in the same group folder (step 5): match their style and keep continuity.

## 4. Decide what each prompt needs

- **HARD GATE** when the issue implies a Live write (S1): a production data write through any `## Data connectors` system marked read-write, a write to any target not listed under `## Dev and sandbox`, or an outbound message. (Merging is covered by every prompt's "Do not merge" line.) The paragraph says: phase 1 is read-only and posts its findings as a comment on the issue, then STOPS for the operator's explicit approval; no writes until approved; the write itself goes through `harness:gated-write`. Without a Live write, the prompt says "No Live writes in this work."
- **Human steps** (uninstalls, console settings, sign-ins): tell the session to leave them to the operator and name the issue that owns them.
- **Open design questions** the issue leaves unsettled: tell the session to settle each in its plan before writing code, and say what makes it hard. Leave the answer to the Lane unless the operator already gave one.
- **Parallel Lanes**: for each pair in this batch, name the overlap: shared files, migrations (whichever merges second renumbers or rebases), shared fixtures or save paths, and merge order when one must land first. Name the sibling issue in each prompt.
- **Test-first helpers**: list the edge cases the tests must cover, taken from the acceptance criteria.

## 5. Write the files

**Where.** `<main checkout>/.lanes/<group>/`, where the main checkout is the parent of `git rev-parse --path-format=absolute --git-common-dir` (the operator launches Lanes from there, and a worktree's own folder disappears when its session closes). The group defaults to the label, or a short slug of the spec title. If this session can't write there (a worktree-isolated session), write to `~/.lanes/<repo name>-<group>/` and say so at the top of the README. Keep both out of `.claude/`: Claude Code guards that folder, so writes there stall on a permission prompt or are refused.

**Keep them out of git**: they're the operator's notes for steering sessions. If `git check-ignore -q <file>` fails, add `.lanes/` to the main checkout's `.git/info/exclude` (local to this clone; the tracked `.gitignore` stays as it is) and say so in the reply.

**`<n>.md`**, under ~400 words, in this shape:

```
/mattpocock-skills:implement GitHub issue #<n> (<title>). Parent spec #<p>, ADR <x>[, GLOSSARY.md (**<term>**)]. Read the issue, spec and ADRs before starting.

<HARD GATE paragraph, or "No Live writes in this work."> Do not merge the PR; merging is the operator's call.

- Scope: <what this Lane builds>. Not in scope: <neighbouring work and the issue that owns it>.
- Reuse: <verified paths/symbols and what each provides>.
- Design question: <question>, settled in the plan.
- Test-first: <edge cases>.
- Parallel: #<m> is being built at the same time; <overlap and what to do about it>.
- After the review: run <each ## Pre-flight command, in order>, commit, list open PRs for overlap as a separate step, then open a PR whose body <## Issues Close convention, e.g. says Closes #<n>>.

Gotchas from #<a>: <quirks and operator rules that apply>.
```

**The opening command.** A prompt opens with exactly one slash command: the Base layer's `implement` and `triage` start only from a slash command the operator types (`disable-model-invocation`), so one prompt can't chain them. Check what's installed with `claude plugin details mattpocock-skills` (its Skills line lists the names).

- Issue labelled with the `needs-triage` role: open with `/mattpocock-skills:triage Let's look at #<n>`, then spell out implement's steps after it.
- Otherwise open with `/mattpocock-skills:implement`.
- If that skill isn't installed or the check fails (the Base layer tracks its main branch, so skills get renamed), open with "Implement GitHub issue #<n> …" and spell out the steps: plan (settle the design questions), build test-first with the tdd skill, run the Pre-flight commands, review with the code-review skill, commit, PR.

**`README.md`** in the group folder: keep earlier waves; add a dated section with this wave's launch lines, and end with a `Later:` line listing what's still blocked and on what.

## 6. Reply

Lead with the launch lines in one code block, one per issue, run from the main checkout:

```
cd <main checkout> && claude -w <group-short>-<n> -n "#<n> <2-3 word name>" "$(cat .lanes/<group>/<n>.md)"
```

(With the home fallback, `$(cat ~/.lanes/<repo name>-<group>/<n>.md)`.)

Then one line per issue, starting with its link: its gates and stopping points, and its overlap with sibling Lanes. Then the blocked issues and what each waits on, and anything left to the operator (`ready-for-human` issues, blocker links that disagree).

## GitHub commands

| Purpose | Command |
| --- | --- |
| Issues with a label | `gh issue list --repo <Repo> --label <label> --state open --json number,title,labels,body,blockedBy` |
| One issue | `gh issue view <n> --repo <Repo> --json number,title,state,labels,body,blockedBy,url` |
| Comments | `gh issue view <n> --repo <Repo> --json comments --jq '.comments[].body'` |
| A spec's sub-issues | `gh issue view <spec> --repo <Repo> --json subIssues` |
| A blocker's state | `gh issue view <n> --repo <Repo> --json state` |
| Open PRs | `gh pr list --repo <Repo> --state open --json number,title,headRefName,url` |

If `gh` rejects the `blockedBy` field (an older `gh`), read the native links with `gh api repos/<Repo>/issues/<n>/dependencies/blocked_by --jq '.[] | {number, state}'`. If that fails too, use the `## Blocked by` lists alone and say so.
