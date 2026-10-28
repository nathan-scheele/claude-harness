# Writing and debugging eval cases

How the Harness eval cases work and the runner's quirks, learned the hard way. Holds no case, so the eval runner skips it. The fake CLIs have their own reference in [fakes/README.md](fakes/README.md).

## A case

```
plugin/evals/<case>/
├── case.yaml         # name, description, tags, runs, execution, scaffold_script
├── prompt.md         # the operator's request, as they would type it
├── fixture-repo.sh   # builds the workspace; often one line calling ../fixtures/<shared>.sh
├── graders/*.md      # one grader per file, the file name is its name
└── mocks/<server>/   # optional: answers for the plugin's own MCP servers
```

Each case runs `runs` times with the plugin and `runs` times without it (the baseline arm). `scripts/run-evals.sh` fails unless every run passes every scored grader and the plugin beats the baseline.

- **Running.** `scripts/run-evals.sh --case <name>`; one `--case` per call (a second replaces the first), so run cases one after another. `--help` prints the runner's options. Runs use real Claude sessions on your credentials: a three-run case is six sessions. Runs from parallel worktrees queue: a second `run-evals.sh` waits until the first finishes, since concurrent runs stall each other's sessions. A wait longer than one case is another worktree's run, not a hang. It prints one line per run (scored graders passed) and each failing grader of a with-plugin run; the runner's full output goes to `results/run.log`.
- **`execution.env`** accepts only `EVAL_*` keys, so nothing can be put on the agent's PATH; fixtures install fakes in the workspace and `append_system_prompt` tells the agent to run them by path (ADR 0007).
- **Tools.** Bash, Write and Edit need both the case's `allowed_tools` and `--allow-tools` (run-evals.sh grants all three to the run).
- **Headless.** No AskUserQuestion: cases assert the Standards' fallback (numbered options in the last message).
- **Needs-config.** A skill or subagent that sends the operator to `/harness:setup-harness` needs a `<name>-needs-config` (or `-needs-setup`) case proving it stops; `scripts/test-eval-tools.sh` fails without one.
- **Gated writes.** A skill or subagent that names `harness:gated-write` reads a data connector before the gate, so one of its cases asserts the connector is never written: a `not_contains` regex on the fake's `calls.log` (e.g. `WRITE|DRYRUN`, the dry run included). `scripts/test-eval-tools.sh` fails without one.

## Fixtures

- The scaffold runs from its own case directory, so `"$(dirname "${BASH_SOURCE[0]}")/../fixtures/..."` and `../fakes/` resolve. Shared builders live in `fixtures/`; a case wrapper calls one and adds its own tweaks.
- The agent works in `$HOME/cwd` inside a temporary home, with the inherited PATH: the real `gh` and `git` are on it, which is why fakes are run by path.
- External systems are fakes inside the fixture that log every call (`bin/notes-db` → `.notes-db/calls.log`, the fake `gh` → `.fake-gh/calls.log`). Create the log on the first call, so "no call at all" is `file_exists: false`.
- Fixture data uses example.com and placeholder names only; the leak check runs on evals too.
- The eval sandbox breaks `/usr/bin/git` and `node` installed under the home directory, refuses writes under `.claude/`, and sometimes denies appends to `.git/info/exclude`. Workarounds: [fakes/README.md](fakes/README.md).

## Mocks

The plugin's MCP servers never start in eval runs. A case answers their tools from `mocks/<server>/` (the live-verifier cases mock the Harness browser as `mocks/browser/`); a `_server.md` with `type: agent` mocks a whole server per case. Mocks stand in only for the plugin's own servers, never for an operator's connectors.

## Graders

Every grader has `type` and optionally `arm`. **`arm: with-only` graders are not scored**: they only show whether the plugin fired. Anything that should count uses `arm: both` (the default).

- **`tool_used`**: `tool`, optional `input_match` (a regex over the call's input as compact JSON), `min` (default 1) and `max`. "Must not call" is `min: 0` and `max: 0`. Whether it counts calls made inside a subagent is unverified; grade a subagent's calls with a regex on the trace.
- **`tool_order`**: `before` and `after`, each one `{tool, input_match}`.
- **`regex`**: `pattern`, `target`, optional `match` (`contains`, the default, `not_contains` or `count:N` for exactly N) and `flags`. Targets: `trace`, `last_message`, `mock_calls`, or `{source: file, path: ...}` for a workspace file.
  - Patterns are JavaScript regexes: no inline `(?s)`; use `[\s\S]`.
  - The trace is JSON lines, so text in it is escaped: a newline is the two characters `\n` (`\b` right after one fails), a quote is `\"` (`[^"]*` stops at it). Write `\\n` in the pattern for a newline.
  - The trace holds every message, subagents' included, and every tool input, including heredocs that quote other text: a pattern for "the agent ran X" anchors at the start of a command or after `&&`, `;`, `||`, a newline or `(` (see `data-digest-*/graders/no-write-command.md`).
  - To keep a match inside one record of a report (one finding, one row), temper the span so it can't cross the next record's marker: `(?:(?!\[(?:MEDIUM|LOW)\])[\s\S]){0,400}?` (see `integration-reviewer-unbatched/graders/finding-at-loop.md`). A bare `[\s\S]{0,N}?` reaches into the next record.
  - Match what must be true, not the one form you expect: a correct run links an issue as `#13`, `issue 13` or `../13/issue.md`, and makes a file with `>`, `tee` or `cp`. To check that a file was made, grade the file (`file_exists`, or a regex on it), not the command that wrote it.
  - Give every lookahead a match it rejects: one the rest of the pattern would accept without it, checked with `check-graders.mjs` against a saved run that should fail. One with nothing to reject is dead weight, and so is the comment that explains it.
- **`llm`**: a judge prompt with PASS and FAIL conditions; `focus` is `last_message`, `trace` or `mock_calls`. `focus: trace` sees only the first and last 12 messages, so a subagent's report in mid-run is invisible to it: use a regex for that. Short, concrete prompts with the expected facts judge reliably; long checklists flake. Name what must be true, not one shape of it: "two steps" fails a run that splits them into three, so say which variations are fine. The last message is all `last_message` sees, so a question split from its preview loses the preview.
- **`file_exists`**: `path`, `exists`. Only files created during the run count (a file the fixture made reads as absent). One file per grader. A `*` works in a directory segment too (`.audit/*/consumers.tsv`), for a path whose folder name the agent picks; bracket globs are unverified.

## Debugging a failure

run-evals.sh saves every run to `results/traces/<case>/<arm>-<n>/` (gitignored): `trace.jsonl`, `mock-calls.jsonl`, `graders.json` (the runner's verdicts) and `workspace/`, the workspace files the case's graders name (as the run left them).

- In a trace, a subagent's messages carry `parent_tool_use_id`; its final report is the Agent call's `tool_result`.
- `scripts/check-graders.mjs <case>` re-grades the saved runs offline (regex on any target, `tool_used`, `tool_order`; it skips `file_exists`, since a saved file doesn't say whether the run made it) and prints a table, one row per grader and one column per run. Edit a grader, re-run it, and watch it go red on the runs it should fail and green on the rest, before spending a real run. A `*` marks a cell where the runner disagreed: either the grader changed since that run, or the checker reads it differently.
- `--llm` also runs the llm graders' judge: three votes per run on the runner's default judge model (haiku, `--judge-model` to change it), majority wins, a split shows its PASS count, `FAIL(1/3)`, and the judge's reason for each FAIL vote on a with-plugin run is listed under the table. It costs a few cheap model calls, not a rerun: fix a judge prompt against the saved runs first.
