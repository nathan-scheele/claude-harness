---
name: followup-capture
description: "Capture a follow-up mid-session: search the tracker for a duplicate first, decide between folding it into the current PR, extending an existing issue or filing a new one and say why, write it with evidence, acceptance criteria, a parent link and the right triage label, then cross-link it from the current PR or issue. Files without asking: writes to the operator's own tracker are pre-authorized. Use when the operator says file it, open an issue for that, add this to #N, fold it into this PR, or open a separate issue."
---

# Followup capture

Goal: a gap found mid-session ends up in exactly one durable place the next session will find, with enough evidence that nobody has to rediscover it, and the operator goes back to their work after one short reply.

Load `harness:standards` first (Skill tool) and follow it, especially S2 pre-authorized checks, S5 deep links, S7 scope discipline and S12 nothing left loose. If it isn't available, carry on with the steps below.

**Pre-authorized.** Writing to the operator's own tracker needs no go-ahead (S2), and "file it" is already the request: file, then report. Never ask "shall I file this?". Ask (S4) only when what "it" refers to is unclear.

Every code-host command lives in **GitHub commands** at the end; always pass `--repo <Repo>` from Project config.

## 1. Read Project config

Read `docs/agents/harness.md` and take `## Code host` **Host** and **Repo**, and `## Issues` **Tracker**. Read `docs/agents/triage-labels.md` if it exists: it maps the triage roles (`needs-triage`, `ready-for-agent`, `ready-for-human`, …) to this repo's label strings; without it, use the role names.

If **Tracker** is missing or `unset`, or **Host** isn't GitHub (v1's only host), write the issue as a draft in your reply for the operator to file, and say `/harness:setup-harness` records the tracker.

## 2. Pin down the item and the current work

- **The item**: one finding per filing, in plain words, with its **evidence** from this session: the file and line or symbol, the command and its output, the error text, a run, PR or page link, and the operator's own example verbatim. If "it" covers several separate findings, file each one.
- **The current work**: the branch's open PR (`gh pr view` with no number), the issue its body closes (`Closes #<n>`), and that issue's parent (its `## Parent` section). Without a PR, the issue the session is working on, from the conversation or the branch name. Done when you know the current PR (or none), the current issue (or none) and the parent.

## 3. Search for duplicates

List the open issues with their bodies (one call, `--limit 200`); in a tracker with more than that, add `--search "<two or three keywords>"`. Compare by meaning, not wording: a duplicate is an open issue describing the same problem or the same piece of work, whatever its title says. Also read the current PR's body: the item may already be a task there.

A **closed** issue that covered the item is not a duplicate: the gap is a regression or something that issue missed, so it goes to a new issue that links the closed one.

## 4. Choose the route

The operator's words decide when they name a route: "add this to #N" extends #N (if #N is closed, file a new issue that links it and say so); "fold it into this PR" folds; "open a separate issue" files a new one, linking any related issue step 3 found.

For a bare "file it", take the first route that fits:

1. **Extend** an open issue that already covers the same problem or work (step 3's duplicate). If it already holds everything you would add, write nothing and say where it is.
2. **Fold into the current PR** when the PR is open on this branch and the item is something the PR already owes: a gap in its issue's acceptance criteria, or a defect its own diff introduced, small enough to finish in this session.
3. **New issue** otherwise.

Write the route down with a one-line reason that names the closest candidate you passed over (the issue that looked similar, or the PR), for step 7.

## 5. Write it

Pass multi-line text with `--body-file -` and a quoted heredoc (`<<'EOF'`), so backticks and `$` arrive intact.

- **Extend**: a comment on the issue (`gh issue comment`), leaving its body as the author wrote it. The comment says what was found, the evidence, where (`Found while working on #<current issue> / PR #<n>`), and any acceptance criterion the issue now needs.
- **Fold**: read the PR body, then write it back unchanged except for one `- [ ] <item>` line under a `## Follow-ups` heading (add the heading if missing) with `gh pr edit --body-file -`. The item is then part of the current work: do it on this branch before the PR is called done.
- **New issue** (`gh issue create`):
  - **Title**: the problem in plain words, not the fix's code.
  - **Body**, in this order: `## Parent` with `#<parent>`; `## What happened` with the evidence; `## What to build`, a sentence or two; `## Acceptance criteria` as `- [ ]` lines, each checkable; then `Found while working on #<current issue> (PR #<n>).` and any related issue from step 3.
  - **Parent**: the current issue's parent, the spec the work hangs under, so the follow-up shows up where that spec is planned. A current issue with no parent is itself the parent. If the item plainly belongs under a different open spec from step 3, use that one and say why. With no current work and no fitting spec, write `None` and say so.
  - **Triage label**: the `needs-triage` role, since nobody has triaged a follow-up filed mid-session. Use `ready-for-agent` only when the operator says it's ready to build, and `ready-for-human` when the work needs a person (a console setting, a sign-in, a purchase). Also copy the grouping labels the parent or current issue carries (a project or spec label, never its triage label), so label-based planning finds the follow-up.
  - If create fails because a label doesn't exist in the repo, file again without that label and say which one was dropped.

## 6. Cross-link

For an extend or a new issue, comment on the current PR with `Follow-up: #<n> <title>` (`gh pr comment`); with no PR, comment on the current issue instead. A fold needs no cross-link: it lives in the PR. With no current PR or issue, skip this and say so.

## 7. Report

At most three lines: the route and its reason from step 4; the issue, comment or PR link (S5); for a new issue, its label and parent. Then carry on with whatever the session was doing.

## GitHub commands

v1 supports GitHub through the `gh` CLI. Always pass `--repo <Repo>` from Project config.

| Purpose | Command |
| --- | --- |
| Current PR | `gh pr view --repo <Repo> --json number,title,body,url,headRefName` (no number: the current branch's PR) |
| An issue | `gh issue view <n> --repo <Repo> --json number,title,body,state,labels,url` |
| Open issues | `gh issue list --repo <Repo> --state open --limit 200 --json number,title,body,labels,url` (add `--search "<keywords>"` for a large tracker) |
| Extend | `gh issue comment <n> --repo <Repo> --body-file - <<'EOF'` … `EOF` |
| Fold | `gh pr edit <n> --repo <Repo> --body-file - <<'EOF'` … `EOF` |
| New issue | `gh issue create --repo <Repo> --title "<title>" --label <triage label> [--label <grouping label>] --body-file - <<'EOF'` … `EOF` |
| Cross-link | `gh pr comment <n> --repo <Repo> --body "Follow-up: #<n> <title>"`, or `gh issue comment <n> …` without a PR |
