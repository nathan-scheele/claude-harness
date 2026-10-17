---
name: ship-and-land
description: "Take an implemented issue from a committed branch to verified production: run the pre-flight checks from Project config, open a PR that closes the issue (body from the Base layer's pr skill), diagnose failing or missing CI checks, stop for the operator's explicit go-ahead before a merge that deploys, merge, watch CI and the deploy with interval status, hand off to the live-verifier subagent, close the issue if the merge didn't, then run close-session. Does not review the code again. Use when the operator says ship it, merge it, land it, open the PR and merge, or take this to production."
---

# Ship and land

Goal: "shipped" means merged, deployed and verified working, with the operator deciding every merge that deploys and never having to ask how it's going.

Load `harness:standards` first (Skill tool) and follow it throughout, especially S1 Live-write gate, S3 live system is truth, S4 structured decisions, S5 deep links, S6 proactive status and S12 nothing left loose. If it isn't available, carry on with the steps below.

**No second code review.** The work arrives from the Base layer's `implement` (or `implement-spec`), which already ran `code-review` on this diff. Don't run `code-review` or any other review skill or subagent, and don't re-read the diff to judge it. If the operator asks for a review, that's a separate request.

Every code-host command lives in **GitHub commands** at the end; the steps name what to do, that section says how. Always pass `--repo <Repo>` from Project config.

## 1. Read Project config

Read `docs/agents/harness.md` and take values by section heading and key:

- `## Code host`: **Host**, **Repo**, **Default branch**.
- `## Pre-flight`: the commands, in order.
- `## CI`: each workflow file, its name and its job ids.
- `## Merge`: **Method** and **Merging deploys**.
- `## Deploy`: **Target**, **Triggered by**, **Live URL**.
- `## Dev and sandbox`, for the verify step.
- `## Issues`: **Tracker** and **Close convention**.

If the file is missing, or any of **Host**, **Repo**, **Default branch**, `## Pre-flight`, **Method** or **Merging deploys** is missing or `unset`, stop before doing anything and tell the operator to run `/harness:setup-harness`, naming what's missing. Never guess. `none` is a real answer: `## Pre-flight` none means no checks; `## Deploy` none means nothing deploys.

v1 ships on GitHub only. If **Host** is anything else, say so and stop.

## 2. Pre-flight

1. **Find the issue.** The one the operator named; else the issue number in the branch name, its commits or an existing PR for the branch. If you can't tell, ask (S4). Read it from the tracker: state, title and its acceptance criteria (step 8 hands them to the verifier).
2. **Check the branch.** You must be on a feature branch, not the default branch. Uncommitted changes to tracked files stop the ship: list them and ask whether they belong in this PR (S4). Never commit or discard them on your own.
3. **Run each `## Pre-flight` command** from the repo root, in order, and report each result in one line. On the first failure, stop: quote the failing output (the first error, not the whole log) and don't open a PR. Fixing it is the operator's call; offer to, and wait.

## 3. Open the PR

1. **Existing PR.** Look for an open PR for this branch. If there is one, use it: don't open a second. Check its body has the closing reference (below) and add it if not.
2. **Push** the branch to the remote (`git push -u <remote> <branch>`). Pushing a feature branch deploys nothing, so it's pre-authorized (S2). Never force-push unless the operator says so.
3. **Write the body.** Invoke the Base layer's `pr` skill through the Skill tool to write the PR body for this branch. If it isn't installed or fails (the Base layer tracks its main branch, so skills get renamed), write the body yourself: a one-line summary, what changed and why in a few bullets, and how it was tested (the pre-flight results). Either way:
   - The body must close the issue the way `## Issues` **Close convention** says (the host's closing keywords are in **GitHub commands**), so merging closes it.
   - No secrets, tokens or personal data.
4. **Open the PR** against **Default branch** with a title naming the change, and post the link (S5).

## 4. Diagnose CI before asking to merge

Watch the PR's checks with the run-monitor procedure. Load `harness:run-monitor` now with the Skill tool, before the first poll, and follow its steps 2-6 for this PR at the operator's interval (60 seconds if they gave none). If it isn't available, follow the polling rules below anyway.

**Polling** (here and in step 7) follows run-monitor step 4. The rule most often broken: one poll per Bash call, then a status line, then the next poll. A loop of polls inside one Bash call goes silent until the end, like a blocking watcher (ADR 0004).

Before asking to merge, put the checks in exactly one of these buckets, with evidence:

- **Green**: every job `## CI` lists for a workflow that runs on PRs ran and passed. A required job that was skipped or never appeared is not green.
- **Real failure**: a test, build, type, lint or migration failure (run-monitor's subagent finds the first failing step and says real or artifact). Report it with the job link and quoted error, and stop: don't ask to merge a red PR. Offer to fix it on the branch (S4); a fix goes through pre-flight and CI again.
- **Flake or reporting artifact**: the work passed but a runner, network or reporting step failed. Say why you think so (run-monitor's verdict). Rerunning the failed jobs is pre-authorized for PR checks (it deploys nothing); rerun once and watch again. If it fails the same way twice, treat it as real.
- **Checks never fired**: no run appeared for the PR's head commit within 3 minutes of opening it, or a listed job is missing. Look for why as soon as the first poll shows no checks, from the workflow files and the PR's state: trigger filters (branches or paths the change doesn't touch), a job-level condition that skipped the job, a draft PR, a merge conflict, or CI disabled for the repo (the host's specifics are in **GitHub commands**). If the workflow files already show that no PR workflow runs for this change, don't wait out the 3 minutes. Report the cause with the evidence (file and line) and what would make the checks run. Don't treat "no checks" as green.

Only **green** goes on to step 5. Anything else, report and stop with the options as a structured decision (S4).

## 5. Merge gate

If **Merging deploys** is `yes`, the merge is a Live write (S1). The request that started this skill ("ship it", "merge it", "land it") is not the go-ahead: it came before the operator saw the PR, the CI result and what would deploy. Post a short merge summary:

- the PR (link), the issue it closes, and the head commit;
- the CI verdict from step 4;
- the merge method from **Method**, into **Default branch**;
- what deploys and where: **Target**, **Triggered by**, **Live URL**.

Then ask for the go-ahead as a structured decision (S4): merge now (Recommended, when green), or hold. Stop and wait. Merge only on an explicit yes to this merge. The one exception: the operator already gave, in this conversation, an explicit go-ahead that names this merge (or "the PR for issue <n>") and accepts that it deploys, such as "you have my go-ahead to squash-merge it into main once CI is green; that deploys to production". Then post the summary and proceed, but only if CI matched their condition (S1, ADR 0008). A go-ahead for an earlier PR, or a bare "ship it", never counts.

If **Merging deploys** is `no`, merging is not a Live write: post the summary and merge once CI is green.

Before merging, read the PR's state again (S3): still open, still mergeable, head commit unchanged since CI ran. If the head changed, go back to step 4.

## 6. Merge

Merge with **Method** from Project config (never another method, never an admin override of failing checks or branch rules). Don't delete the branch unless the operator asks. Post one line: merged, the merge commit (short SHA) and the PR link.

If the merge is refused (a required check, a review rule, the branch is behind), report the reason and stop; updating the branch means a new head, so it goes back through step 4.

## 7. Watch CI and the deploy

Use the run-monitor procedure again (`harness:run-monitor` steps 2-6, and the polling rules in step 4) for the runs on **Default branch** at the merge commit: find them by the full merge-commit SHA, state the expected outcome, then poll, one Bash call and one status line per interval (S6). The expected outcome includes the deploy named in `## Deploy` **Triggered by**: its job must run, not be skipped. If `## Deploy` is `none`, say nothing deploys and watch CI only.

Report the result against the expectation. If the deploy failed, was skipped or never started, stop here: say what is (and isn't) live, with links. Don't verify a deploy that didn't happen, and don't close the issue. Offer to file a follow-up issue (S4, S12).

## 8. Verify live

Hand off to the Harness live-verifier subagent with the Agent tool (`subagent_type: harness:live-verifier`). Tell it what to verify: the issue link and its acceptance criteria as written (copy them from the issue, so the subagent doesn't depend on reaching the tracker), and the target: `live` after a production deploy, or the `## Dev and sandbox` name the merge deployed to. Pass the PR link and deployed commit. It returns a verdict and a pass/fail table.

- Post the verdict and the table as it came back.
- `WAITING`: relay its Human steps to the operator, wait for "done", then resume it with the steps marked done.
- `FAIL`: report the failing rows. Don't close the issue (step 9); offer a follow-up issue or a fix (S4).
- `BLOCKED`: report why and what clears it.

If the live-verifier subagent isn't available, do a read-only check of **Live URL** yourself, say plainly that the acceptance criteria weren't verified, and list that as owed (S12).

## 9. Close the issue

Read the issue's state from the tracker (S3). The closing reference in the PR usually closed it on merge.

- Closed: say so, with the link.
- Still open and verification passed: close it yourself (an issue in the operator's own tracker is pre-authorized, S2) with a one-line comment linking the PR, the merge commit and the verification verdict.
- Verification failed or didn't run: leave it open, or if the merge already closed it, say so and offer to reopen it (S4).

## 10. Close the session

Post the final report: one line per stage (pre-flight, PR, CI, merge, deploy, verify, issue) with links, then anything still owed (S12). Then invoke `harness:close-session` (Skill tool) to finish: it checks everything landed or is recorded, stops what the session started and removes the worktree. If it isn't available, say the session still needs closing out.

## GitHub commands

v1 supports GitHub through the `gh` CLI. Every code-host command ship-and-land uses is here, so supporting another host means another version of this section. Always pass `--repo <Repo>` from Project config. CI and deploy watching also uses the commands in `harness:run-monitor`'s own GitHub section.

| Purpose | Command |
| --- | --- |
| Read the issue | `gh issue view <n> --repo <Repo> --json number,title,state,body,url` |
| Existing PR for the branch | `gh pr list --repo <Repo> --head <branch> --state open --json number,url,body,headRefOid` |
| Open the PR | `gh pr create --repo <Repo> --base <Default branch> --head <branch> --title "<title>" --body-file <file>` |
| Add the closing reference | `gh pr edit <n> --repo <Repo> --body-file <file>` |
| PR state before merging | `gh pr view <n> --repo <Repo> --json state,mergeable,mergeStateStatus,headRefOid,isDraft,url` |
| PR checks | `gh pr checks <n> --repo <Repo>` (exit 8 means still pending; "no checks reported" means none fired) |
| Runs for the PR's head | `gh run list --repo <Repo> --commit <full head sha> --json databaseId,workflowName,status,conclusion,event,url` |
| Rerun failed PR jobs (flake) | `gh run rerun <id> --repo <Repo> --failed` |
| Merge (after the gate) | `gh pr merge <n> --repo <Repo> --<squash or merge or rebase>` |
| Merge commit | `gh pr view <n> --repo <Repo> --json state,mergeCommit,mergedAt` |
| Close the issue | `gh issue close <n> --repo <Repo> --comment "<comment>"` |
| Offer a reopen (on a yes) | `gh issue reopen <n> --repo <Repo>` |

Never `gh pr merge --admin`, never `--auto` without the operator asking, and never `gh run watch` or `gh pr checks --watch` (they go silent; ADR 0004).

GitHub specifics:

- **Closing reference**: a body line `Closes #<n>` (or `Fixes`, `Resolves`) closes the issue when the PR merges into the default branch, not into any other branch.
- **Why checks don't fire**: a workflow runs on PRs only if its `on:` has `pull_request` (or `pull_request_target`) and the PR matches its `branches` (the base branch) and `paths` filters; a job's `if:` can skip it. GitHub runs no `pull_request` workflow while the PR has a merge conflict (`mergeable` is `CONFLICTING`). Draft PRs run workflows unless a job's `if:` checks `draft`. Actions can be disabled for the repo or a workflow (`gh workflow list --repo <Repo> --all` shows `disabled_manually`).
