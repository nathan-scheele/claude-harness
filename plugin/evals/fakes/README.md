# Eval fakes

Stand-ins for CLIs that eval cases must never reach for real. This directory holds no case, so the eval runner skips it.

## `gh`

A fake GitHub CLI (pattern: [ADR 0007](../../../docs/adr/0007-eval-cli-fakes.md)) that replays canned run, PR and issue states from a scenario directory and appends every call to `calls.log`, errors included. Needs `jq`. Tests: `scripts/test-fake-gh.sh`.

### Using it in a case

The runner can't put anything on the agent's PATH (`execution.env` takes only `EVAL_*` keys, and the inherited PATH holds the real `gh`), so the case installs the fake into the workspace and names it in the system prompt.

In the case's scaffold script (scaffolds run from their own case directory, so `../fakes` resolves):

```bash
FAKE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fakes" && pwd)/gh"
mkdir -p .fake-gh/bin .fake-gh/runs .fake-gh/prs
cp "$FAKE" .fake-gh/bin/gh
chmod +x .fake-gh/bin/gh
echo .fake-gh/ >> .git/info/exclude   # after git init, so it never shows as untracked
```

then write the scenario under `.fake-gh/`. In `case.yaml`:

```yaml
execution:
  append_system_prompt: >
    This sandbox has no network and no real GitHub CLI. A stand-in GitHub CLI
    is installed at .fake-gh/bin/gh in the working directory; run it by that
    path wherever you would run `gh`, and tell any subagent you start to do the same.
```

Graders read `.fake-gh/calls.log` (one `gh <args>` line per call) with a `regex` grader and `target: {source: file, path: .fake-gh/calls.log}`, or match `gh\s+<subcommand>` in Bash inputs with `tool_used`.

### Scenario directory

| Path | What it holds |
| --- | --- |
| `repo` | `owner/name`, used in URLs the fake makes up (issue create). |
| `runs/<id>/run.json` | The run's fixed fields: `databaseId`, `workflowName`, `path` (`.github/workflows/<file>`), `headBranch`, `headSha`, `event`, `displayTitle`, `url`; optionally `startsOn` (below). |
| `runs/<id>/timeline.jsonl` | One JSON object per tick, merged over `run.json`: `status`, `conclusion`, `jobs` (each with `databaseId`, `name`, `status`, `conclusion`, `steps` of `number`, `name`, `status`, `conclusion`). |
| `runs/<id>/log-failed.txt`, `log.txt` | What `gh run view <id> --log-failed` / `--log` print once the run has completed. |
| `runs/<id>/jobs/<job id>.log`, `<job id>.failed.log` | Optional per-job logs for `--job <id> --log` / `--log-failed`; otherwise the run-level log is used. |
| `prs/<n>.json` | Fixed PR fields for `gh pr view <n>` (`headRefName` links it to runs for `gh pr checks`). |
| `next-pr` | The number `gh pr create` gives the first PR it opens (default 100). |
| `default-branch` | The default branch (default `main`): `pr create`'s base, and where a merge closes issues. |
| `issues.json` | Existing issues for `gh issue list` / `view` (default `[]`), with the fields `--json` asks for: `number`, `title`, `state` (`OPEN` or `CLOSED`), `body`, `url`, and optionally `labels` (`[{"name": ...}]`), `blockedBy` (GitHub's native links: `{"nodes": [{"number", "state"}], "totalCount"}`), `subIssues`, `comments` (`[{"body": ...}]`, shown by `--json comments`; `--comments` prints only the issue). |

### Git in the eval sandbox

On macOS the eval sandbox blocks the Command Line Tools behind `/usr/bin/git`, so plain `git` fails there. A fixture that needs git gives the agent a wrapper for a git that works (`.fake-gh/bin/git` in `plugin/evals/fixtures/ship-and-land-repo.sh`, which fails the case if there is none). Even then, a push that sends new commits to a local bare remote fails, because the receiving side spawns the blocked git; push the branch in the fixture so the agent's push has nothing to send. The live-verifier hook allows `gh` only by its bare name, so live-verifier can't run this fake by path: hand it the acceptance criteria instead.

### Faked time

Every status read (`run list`, `run view` without a log flag, `pr checks`) advances one shared tick, and each run shows the timeline line for the current tick, staying on its last line once past the end. A run with six timeline lines takes six polls to finish, however long the agent waits between them, so a case can set a short polling interval and still grade several status updates. Log reads don't advance time; asking for logs before a run completes fails as the real CLI does. `run watch` and `pr checks --watch` jump straight to the final state, as a blocking watcher would. The tick counter isn't locked, so two status reads at the same moment (the main session and a subagent polling in parallel) can share or skip a tick; keep polling in one place.

### Opening and merging PRs

`pr create` records the PR in `state/prs/<n>.json` (OPEN, with its body, from `--body` or `--body-file`) and refuses a second open PR for the same branch; `pr list` and `pr view` see it, and `pr view` with no number finds the current git branch's open PR. `pr merge <n>` needs `--squash`, `--merge` or `--rebase`, marks the PR MERGED, and closes any issue its body names with a closing keyword (`Closes #11`) when it merges into the default branch, as GitHub does. `pr edit` changes a PR's title, body or base. `pr merge --auto` is refused: on GitHub it only arms auto-merge. `issue close` and `issue reopen` change an issue's state; their `--comment`, like `issue comment`, adds a comment that `issue view --json comments` shows. `workflow list` lists the workflows the scenario's runs belong to, all active.

A run whose `run.json` has `"startsOn": "pr-open:<branch>"` or `"merge:<branch>"` doesn't exist until a PR for that branch is opened or merged; its timeline then starts at its first line. A merge gives the PR the `headSha` of a run that starts on that merge as its merge commit, so the agent can find the run by commit.

### Supported commands

`run list` (filters: `--workflow` file or name, `--branch`, `--commit`, `--status`, `--event`, `--limit`), `run view` (`--json`, `--jq`, `--log`, `--log-failed`, `--job`, `--exit-status`), `run watch`, `workflow list`, `pr create`, `pr list` (`--head`, `--base`, `--state`, `--limit`), `pr view`, `pr edit`, `pr checks`, `pr merge`, `issue list` (newest first; `--state`, default open; `--label`, repeated or comma-separated, all must match; `--limit`; `--search` is accepted and ignored), `issue view`, `issue create` (prints a made-up URL and records the issue in `state/created-issues.jsonl`), `issue close`, `issue reopen`, `issue comment`, `auth status`, `--version`. `--repo` is accepted and ignored. Anything else exits 1 with the list of supported commands; extend the fake (test first) when a skill needs more.
