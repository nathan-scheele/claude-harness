---
name: close-session
description: "Close out a work session: confirm every piece of work is landed (merged or deployed) or recorded somewhere durable (issue, PR, memory), stop what the session started, remove its worktree, then give a safe-to-clear verdict and a paste-ready priming prompt for the next session. Use when the operator says close out, wrap up, I'm done, end the session, is it safe to clear, or close the worktree."
---

# Close session

Goal: the operator can `/clear` or close the window and lose nothing. Every piece of work the session touched ends **landed** (merged, deployed, verified) or **recorded** (written where a future session will find it). Then clean up, give a verdict, and hand over a prompt for the next session.

Load `harness:standards` first (Skill tool) and follow it throughout, especially S8 clean up after, S9 isolation and S12 nothing left loose. If it isn't available, carry on with the steps below.

Gather every fact with tools, not from memory of the conversation (S3).

**Never, as part of closing out:** merge, push to the default branch or anything that deploys, force-push, delete a remote branch, close a PR, drop or pop a stash this session didn't create, or discard commits or uncommitted work that hasn't landed. Those are Live writes (S1) or other sessions' state (S9); if one is needed, name it as a blocker and stop.

## 1. Find the default branch and remote

In order, stop at the first that answers:

1. Project config: if `docs/agents/harness.md` exists and names the code host, remote or default branch, use it.
2. `git symbolic-ref --short refs/remotes/origin/HEAD` (prints e.g. `origin/main`).
3. `git remote show origin` and read its `HEAD branch:` line.

If there is no Project config, say once that the Harness setup skill writes one, and carry on with git. If none answers, ask the operator (S4) instead of guessing. Below, `<default>` means that branch on that remote, e.g. `origin/main`.

## 2. Inventory the git state

From the session's working directory (its worktree, if it has one):

- `git status --short`: uncommitted and untracked files.
- `git fetch -q <remote>`, then `git log --oneline <default>..HEAD`: commits not on the default branch by SHA.
- `git rev-parse --abbrev-ref @{u}` and `git log --oneline @{u}..HEAD`: whether the branch has an upstream and anything unpushed.
- The branch's PR, from the code host found in step 1. On GitHub (v1's only host): `gh pr list --head <branch> --state all`. If the host can't be reached, say so and rely on git.
- `git stash list`: only entries this session created, matched by its own tags. The stash is shared across worktrees; never touch the others.

**Squash merges change SHAs.** A squash-merged branch still shows its commits in `<default>..HEAD`. Prove landing by content instead: list the paths the branch changed with `git diff --name-only $(git merge-base <default> HEAD) HEAD`, then run `git diff --stat HEAD <default> -- <those paths>`. Empty output means the work landed. A whole-tree diff against `<default>` is normally non-empty once the default branch moves on; that is not a blocker.

Classify each uncommitted file:

- **Drift** the session didn't mean to make (regenerated files, lockfile churn): say so; it can be discarded once the operator agrees.
- **Real work**: a blocker until it is committed and pushed, or the operator says to drop it.

## 3. Stop what the session started

Check the conversation for each of these, confirm its state with tools (the background task list, `pgrep`), and stop it or confirm it already finished:

- Background shell tasks and monitors: stop them if they are still running and no longer needed.
- Local servers and watchers: stop them by process group and confirm with `pgrep`.
- Browser pages the session opened: close them, so a shared profile isn't left locked.
- Subagents still running: wait for them or report them as running. Never claim their results.
- Deploys and CI runs in flight: report their status. Never call a session safe to clear mid-deploy.

Only stop what this session started. Leave other sessions' processes alone (S9).

## 4. Account for follow-ups

List everything the session still owes: post-deploy checks, review findings left for later, questions waiting on someone, fixtures left in a modified state, the next ticket.

Each one must be **recorded** in at least one durable place; write it there if it isn't (writes to the operator's own issue tracker are pre-authorized, S2):

- The issue tracker: an unchecked item in the PR description, an issue comment, or a new issue (look for an existing one first).
- Project memory, if the session uses one: status, absolute dates, SHAs, PR and issue numbers, what's owed.

Something said only in chat is **not** recorded (S12).

## 5. Verdict

Give a short list: what landed (with PR, SHA or deploy evidence and a link, S5), what is recorded and where, and anything that is neither. Then one explicit line:

- **Safe to clear: yes.** Everything is landed or recorded and nothing the session started is still running.
- **Safe to clear: no.** Name each blocker and what would clear it (commit and push, open a PR, merge, record it, wait for the deploy). Offer to do the parts that aren't Live writes, then stop and wait. Don't remove the worktree or give a priming prompt yet; run close-session again once the blockers are cleared.

## 6. Retro check (only when safe)

Skip this step if `/retro` already ran in this session. Otherwise look back over the conversation for moments where the session struggled:

- The operator corrected you, undid your work, or had to repeat an instruction.
- A test, check, CI run or review caught a mistake you made.
- Finding a file or fact took three or more searches.
- You needed information you couldn't reach (a log, a service, a dashboard) and had to ask or guess.

If you find any, name up to three, one line each (what happened, and when), and suggest the operator run the Base layer's `/retro` before clearing, while this session is still in context. Only the operator can invoke it. Its changes are new work: make them on a new branch off `<default>`, not the branch that just landed, then run close-session again. Carry on with the next steps either way; this is a suggestion, not a stop. If `/retro` isn't installed (the Base layer added it in 1.3.0), record the struggles in the tracker as in step 4 instead.

## 7. Remove the worktree (only when safe)

If the session runs in a worktree it created for this work:

- Everything landed (step 2 proved it by content): leave the worktree with Claude Code's worktree tool (`ExitWorktree`, action `remove`). If it refuses because the branch has commits not on the default branch by SHA, retry with `discard_changes: true` and say plainly that the discarded commits are branch history already squashed into the default branch.
- Pushed but not merged (open PR): keep the worktree unless the operator asks to remove it; the remote branch holds the work.
- Any doubt: keep it and ask (S4).

Not in a worktree: leave the checkout as it is and say so.

## 8. Priming prompt

When the verdict is yes, end with a priming prompt in a fenced code block: one paste-ready message that starts the next session with the right context. It must stand on its own for a fresh session that has none of this conversation:

- The repo and its path, and the branch to start from.
- What just landed, as PR or issue links and SHAs.
- What to pick up next, pointing at the issue, PR, memory file or doc that holds the detail. Link to it; don't restate it.
- Which skills to start with, if any.
- No secrets, tokens or personal data.

Put one short plain line directly above the code block saying what it is and when to use it, e.g. "To pick this up in a fresh session, paste this as your first message after `/clear` (or in a new window):". A bare label like "Priming prompt:" doesn't say that.

Write the prompt yourself. If the next session needs more than a prompt can carry, suggest the operator run the Base layer's `/handoff` if it is installed (only the operator can invoke it) and reference the document it writes; if it isn't, put the extra detail in the tracker in step 4 and link it.

Close with one line: what was removed or kept, and that the session is safe to clear (after `/retro`, if step 6 suggested it).
