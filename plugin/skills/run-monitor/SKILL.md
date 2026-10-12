---
name: run-monitor
description: "Watch a CI run, deploy, workflow or long job the operator started: poll it from the main session at an interval the operator can set, post a status line every interval, check the outcome against what was expected before calling it done, and on failure hand the logs to a subagent that finds the first failing step and says whether the failure is real or a reporting artifact. Reads only; files an issue for a real defect only when the operator says yes. Use when the operator says monitor it, watch it, keep an eye on CI or the deploy, tell me when it's done, or I kicked it off."
---

# Run monitor

Goal: the operator never has to ask "how's it going?", and "finished" never hides a wrong result. You watch from the main session and speak every interval (ADR 0004); log digging goes to a subagent so raw logs stay out of this conversation.

Load `harness:standards` first (Skill tool) and follow it throughout, especially S3 live system is truth, S5 deep links, S6 proactive status, S12 nothing left loose and S4 structured decisions. If it isn't available, carry on with the steps below.

**Reads only.** Never rerun, cancel, approve, merge, push or deploy anything, and never write to the system you are watching. Where a fix or rerun would help, say so and hand the operator the one-line command (S13); rerunning a deploy is a Live write (S1). The one write is an issue in the operator's own tracker. That would be pre-authorized (S2), but whether a failure deserves an issue is the operator's call, so this skill offers it and files only on a yes (step 7).

## 1. Read Project config

Read `docs/agents/harness.md` and take values by section heading and key:

- `## Code host`: **Host**, **Repo** (passed as `--repo` to every host command) and **Default branch**.
- `## CI`: each workflow file, its name and its job ids.
- `## Deploy`: **Triggered by** (which workflow or job deploys) and **Live URL**.
- `## Issues`: **Tracker**, where step 7 files an issue.

v1 watches code-host runs on GitHub only (**GitHub commands** below). If **Host** is anything else, say so and stop, unless the operator tells you how to read the run's status.

If the file is missing, or a value this watch needs is missing or `unset`, stop before polling: say which value is missing and tell the operator to run `/harness:setup-harness`. Never guess it from the repo. A CI or deploy watch needs **Repo** and the matching `## CI` or `## Deploy` values. `none` is a real answer (e.g. `## Deploy` none means nothing deploys; say so instead of waiting for a deploy). A job the operator started outside the code host (a script, a backfill, an import) needs no Project config if the operator says how to read its progress (a process, log file or status command).

## 2. Find what to watch

Work from what the operator gave: a run URL or ID, a PR number, a branch, a commit, "the deploy". On GitHub, list candidate runs with the commands in **GitHub commands** below, filtered by the workflow file from Project config and the branch or full commit SHA. If more than one run fits and the operator's words don't settle it, ask (S4) rather than pick.

Open with one short message: what you are watching, with a link (S5); the interval, and that the operator can change it ("check every 2 minutes"); and what a correct outcome looks like (step 3).

## 3. Write down the expected outcome

Before the first poll, state what "done right" means, so the end check has something to compare against:

- **CI run**: every job Project config lists for that workflow runs and passes. A skipped or missing job is a finding, not a pass. Project config holds job ids; the run reports display names, which differ when a job sets `name:` in the workflow file or runs a matrix (`test (18)`, `test (20)`). Map ids to names from the workflow file before comparing, so a renamed job isn't reported missing.
- **Deploy**: the run named in `## Deploy` **Triggered by** completes, its deploy job actually runs (not skipped), and the **Live URL** answers afterwards.
- **Job**: the counts and side effects the operator named (rows imported, records written, messages queued, files produced). If they named none and the job has an obvious count, say which one you will check.

## 4. Poll from the main session

- **Interval**: the operator's, if they gave one; otherwise 60 seconds for CI and deploys, 5 minutes for jobs expected to run longer than an hour. Change it whenever the operator asks.
- **Each poll** is one Bash call that waits, then reads state: `sleep <seconds>; <status command>`. Read once straight away without waiting. A foreground Bash call times out after at most 10 minutes; for a longer interval, or where a foreground wait is refused, start `sleep <seconds>` with `run_in_background` and read state when it finishes.
- **After every poll, post one status line** before waiting again, even when nothing changed: elapsed time, overall state, each job's state (done, running with its current step, queued), what comes next, and the run link. For example: `3m in: lint passed, test running (step 3 "Run tests"), deploy queued. Next check in 60s. <link>`.
- **No silent watchers.** Don't use `gh run watch`, `gh pr checks --watch` or a subagent or background script that only reports at the end; they go quiet for the whole run (ADR 0004).
- **Read, don't recall.** If the operator asks mid-watch, read live state before answering (S3).
- **Superseded runs.** If the run is cancelled because a newer run replaced it, say so, link the newer run, and follow it.
- **Read errors.** If a status read fails, say so in that interval's line and retry next interval. After three failures in a row, stop and report what you last knew.

Stop polling when the run reaches a final state or the operator says stop.

## 5. Check the outcome against the expectation

A green run is not done until it matches step 3. Check each expectation against the live system with read-only reads (S2, S3):

- Jobs that ran versus the jobs Project config lists. Name any that were skipped, cancelled or missing, and what that means (a skipped deploy job means nothing shipped).
- Counts and side effects: read them from the run's output or the live system, and give expected versus actual.
- Deploys: request the **Live URL** read-only (e.g. `curl -sS -o /dev/null -w '%{http_code}' <url>`) and report the status code. Deeper checks of the live system belong to the Harness live-verifier subagent, if it is installed.

Then give the final report: one verdict line (done as expected, done but not as expected, or failed), the evidence, and links. A green run that missed an expectation is "done but not as expected", never a plain success.

## 6. On failure, delegate the log digging

Don't read raw logs in the main session. Start one subagent with the Agent tool: the built-in `Explore` agent (read-only), or `general-purpose` told to stay read-only if `Explore` isn't available. Give it:

- The run ID and link, the repo, and the read-only commands to use: the failed run's jobs and steps as JSON, its failed-step log, and a job's full log when needed (see **GitHub commands**), plus the repo checkout for reading source.
- Anything this session knows about running commands here (tool paths, wrappers), so its commands work.
- What to return, in at most 15 lines:
  1. The **first failing step**: job, step number and name, in run order. Steps that failed only because an earlier one did (an upload of a report that was never written, a cleanup) are not the first failing step.
  2. Up to 10 quoted error lines from that step.
  3. A verdict, **real** or **reporting artifact**, with the reason. Real: a test or assertion failure, a build, type or lint error, a migration error, a deploy the target rejected. Artifact: the work succeeded but a later reporting or notification step failed, the runner or network flaked (dependency download timeout, lost runner), the run was cancelled by a newer one, or a status check read stale state.
  4. For a real failure, the likely cause with `file:line` if the source shows it.

Report to the operator: the first failing step with a link to its job (S5), the quoted error, and the verdict with its reason. If the subagent's answer doesn't hold up against the step list you already have, say so instead of passing it on.

## 7. Offer to file an issue for a real defect

For a real defect, look for an existing open issue first in the **Tracker** from Project config (search for the failing test or error). Then offer to file one as a structured decision (S4), with a draft title and a two-to-three line body (failing step, error, run link). Wait for the answer; file only on a yes, in that tracker, then link the new issue. If **Tracker** is missing or `unset`, offer the draft for the operator to file instead.

For a reporting artifact, don't offer an issue for the code. Say what would clear it (a rerun of the failed jobs, as a one-line command the operator runs) and, if the same artifact keeps recurring, offer an issue about the pipeline instead.

Anything else the watch turned up that the operator still owes (a follow-up check, a skipped job to look into) goes in the final report as a follow-up (S12).

## GitHub commands

v1 supports GitHub through the `gh` CLI; every host-specific command is here, so another host means another version of this section. Always pass `--repo <Repo>` from Project config.

| Purpose | Command |
| --- | --- |
| Find runs | `gh run list --repo <Repo> --workflow <file> --branch <branch> --limit 5 --json databaseId,status,conclusion,displayTitle,headBranch,headSha,event,url` (add `--commit <full sha>`; a short SHA matches nothing) |
| PR checks | `gh pr checks <n> --repo <Repo>` (exit 8 means still pending) |
| Run state | `gh run view <id> --repo <Repo> --json status,conclusion,jobs,url` |
| Failed-step log (subagent) | `gh run view <id> --repo <Repo> --log-failed` |
| One job's log (subagent) | `gh run view --repo <Repo> --job <job id> --log` |
| Existing issues | `gh issue list --repo <Repo> --search "<failing test or error>" --state open` |
| File an issue (after a yes) | `gh issue create --repo <Repo> --title "<title>" --body "<body>"` |

Logs are only available once the run has completed. Never use `gh run watch` or `gh pr checks --watch` for monitoring (step 4).
