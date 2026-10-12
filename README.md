# claude-harness

The Harness: a Claude Code plugin of stack-agnostic skills and subagents for the daily delivery loop (shipping, Live writes, monitoring, verification), layered on [Matt Pocock's skills](https://github.com/mattpocock/skills).

It installs as the plugin `harness`, so its skills live under the `harness:` namespace (e.g. `/harness:standards`). Claude Code reserves plugin names starting with `claude-`, so the plugin can't share the repo's name.

**Status:** walking skeleton. Ships the Standards skill; the workflow skills and subagents land in 0.1 and 0.2.

## Install

### 1. Base layer (required)

The Harness calls Matt Pocock's skills by name instead of copying them. Install them from his own marketplace so you track his main branch:

```
claude plugin marketplace add mattpocock/skills
claude plugin install mattpocock-skills@mattpocock
```

If you already have them from another marketplace (for example the official one, which can lag behind), uninstall that copy first so the two don't shadow each other.

**Upgrade note:** current versions of the Base layer name the per-repo domain doc `GLOSSARY.md` instead of `CONTEXT.md`. In repos set up with an older version, rename `CONTEXT.md` to `GLOSSARY.md` (and any `CONTEXT-MAP.md` to `GLOSSARY-MAP.md`) so its skills find it.

### 2. The Harness

```
claude plugin marketplace add nathan-scheele/claude-harness
claude plugin install harness@harness
```

## What's in it

| Skill | What it does |
| --- | --- |
| `harness:standards` | The 14 Standards (S1-S14) every Harness skill and subagent follows: Live-write gate, pre-authorized checks, live system as truth, structured decisions, deep links, proactive status, scope discipline, cleanup, isolation, browser etiquette, short and plain output, nothing left loose, one-line commands, off-by-default changes. Model-invoked as a reference. |
| `harness:close-session` | Ends a session cleanly: checks every piece of work is landed (squash merges proved by content) or recorded in an issue, PR or memory, stops what the session started, removes its worktree, then gives a safe-to-clear verdict and a paste-ready priming prompt for the next session. Never merges, deploys, deletes remote branches, closes PRs or drops other sessions' stashes. |
| `harness:setup-harness` | Writes the repo's Project config (`docs/agents/harness.md`): detects code host, repo slug, default branch, CI workflows and pre-flight commands, asks only for the rest, previews, then writes. Other Harness skills read it instead of guessing. Run once per repo. |
| `harness:gated-write` | Runs a production data write through the Live-write procedure: read-only fact pass, change table posted to chat and the issue, a stop for explicit approval, dry run, canary of 1-3 records, operator spot-check, full run with progress, re-check against the live system, and a rollback ledger (CSV of before/after values) posted on the issue. Reads data connectors and dev/sandbox targets from Project config; dev and sandbox writes skip the gate. |
| `harness:run-monitor` | Watches a CI run, deploy or long job from the main session: polls at an interval you set and posts a status line each time, checks the outcome against what was expected (jobs listed in Project config, counts, side effects) before calling it done, and on failure has a subagent find the first failing step and say whether it's a real defect or a reporting artifact. Reads only: it offers to file an issue for a real defect and files one only on your yes. |

Vocabulary (Harness, Base layer, Live write, Project config and the rest) is defined in [GLOSSARY.md](GLOSSARY.md); design decisions are in [docs/adr](docs/adr).

## Development

Layout: the marketplace manifest is at `.claude-plugin/marketplace.json`; the plugin itself is in `plugin/`.

```
claude plugin validate --strict .        # marketplace
claude plugin validate --strict plugin   # plugin
scripts/test-leak-check.sh               # leak-check tests
scripts/test-setup-detect.sh             # setup-harness detector tests
scripts/test-fake-gh.sh                  # fake gh used by eval fixtures (plugin/evals/fakes)
scripts/leak-check.sh .                  # fail on emails, home paths, store domains, theme IDs, account subdomains, chat and resource IDs
scripts/run-evals.sh                     # behavioural evals vs a no-plugin baseline (uses your Claude credentials)
```

CI runs strict validation and the leak check on every push and PR. Private identifiers the leak check must catch but this public repo must not contain (a work domain, a store name) go in the `LEAK_PATTERNS` repository secret, one extended regex per line.

Evals live in `plugin/evals/<case>/`. Each case builds a fixture repo with its scaffold script and runs once with the plugin and once without; `run-evals.sh` fails unless every case passes and the plugin beats the baseline. Eval runs are headless, so the structured question tool (AskUserQuestion) isn't available in them; cases assert the Standards' headless fallback instead. Fixture builders shared by several cases live in `plugin/evals/fixtures/`; external systems are fakes inside the fixture that log their calls (the gated-write cases' `bin/notes-db` data connector), so graders check what was actually called and in what order. Stand-ins for CLIs several skills use live in `plugin/evals/fakes/` (a fake `gh` that replays canned CI, PR and issue states and records every call); fixtures install them, as its README describes.

## Credits

The reviewer-subagent structure is borrowed from [claude-code-ultimate-guide](https://github.com/FlorianBruniaux/claude-code-ultimate-guide).

## License

[MIT](LICENSE)
