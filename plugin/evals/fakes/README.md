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
| `runs/<id>/run.json` | The run's fixed fields: `databaseId`, `workflowName`, `path` (`.github/workflows/<file>`), `headBranch`, `headSha`, `event`, `displayTitle`, `url`. |
| `runs/<id>/timeline.jsonl` | One JSON object per tick, merged over `run.json`: `status`, `conclusion`, `jobs` (each with `databaseId`, `name`, `status`, `conclusion`, `steps` of `number`, `name`, `status`, `conclusion`). |
| `runs/<id>/log-failed.txt`, `log.txt` | What `gh run view <id> --log-failed` / `--log` print once the run has completed. |
| `runs/<id>/jobs/<job id>.log`, `<job id>.failed.log` | Optional per-job logs for `--job <id> --log` / `--log-failed`; otherwise the run-level log is used. |
| `prs/<n>.json` | Fixed PR fields for `gh pr view <n>` (`headRefName` links it to runs for `gh pr checks`). |
| `issues.json` | Existing issues for `gh issue list` / `view` (default `[]`). |

### Faked time

Every status read (`run list`, `run view` without a log flag, `pr checks`) advances one shared tick, and each run shows the timeline line for the current tick, staying on its last line once past the end. A run with six timeline lines takes six polls to finish, however long the agent waits between them, so a case can set a short polling interval and still grade several status updates. Log reads don't advance time; asking for logs before a run completes fails as the real CLI does. `run watch` and `pr checks --watch` jump straight to the final state, as a blocking watcher would. The tick counter isn't locked, so two status reads at the same moment (the main session and a subagent polling in parallel) can share or skip a tick; keep polling in one place.

### Supported commands

`run list` (filters: `--workflow` file or name, `--branch`, `--commit`, `--status`, `--event`, `--limit`), `run view` (`--json`, `--jq`, `--log`, `--log-failed`, `--job`, `--exit-status`), `run watch`, `pr view`, `pr checks`, `issue list`, `issue view`, `issue create` (prints a made-up URL and records the issue in `state/created-issues.jsonl`), `auth status`, `--version`. `--repo` is accepted and ignored. Anything else exits 1 with the list of supported commands; extend the fake (test first) when a skill needs more.
