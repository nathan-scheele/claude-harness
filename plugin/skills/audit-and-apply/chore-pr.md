# Code audit: one chore PR

The apply step for consumers that are files in a repo. Opening a PR is pre-authorized (S2); merging it is not. v1 opens PRs on GitHub only: if `## Code host` **Host** is anything else, make the commit, say so, and leave the PR to the operator.

1. Work in a git worktree off the default branch (S9), on a branch named `chore/<slug>`.
2. Make each safe fix, and nothing else (S7).
3. Run the `## Pre-flight` commands from Project config, in order. If a fix breaks one, revert that fix and move its finding to risky, with the failure as the reason.
4. Commit, push, and open one PR against the default branch (`gh pr create --repo <Repo> --base <Default branch>`): a body listing the fixes by check (from the Base layer's `pr` skill when it's installed), with a link to the audit issue. Add the remainder issue's link to the body once step 7 files it.
5. Leave the PR open. Merging is the operator's call, through `harness:ship-and-land`, which stops for the go-ahead when merging deploys.

Then return to step 6 (Re-diff) of the skill, reading the PR branch.
