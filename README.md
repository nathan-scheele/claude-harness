# claude-harness

The Harness: a Claude Code plugin of stack-agnostic skills and subagents for the daily delivery loop (shipping, Live writes, monitoring, verification), layered on [Matt Pocock's skills](https://github.com/mattpocock/skills).

It installs as the plugin `harness`, so its skills live under the `harness:` namespace (e.g. `/harness:standards`). Claude Code reserves plugin names starting with `claude-`, so the plugin can't share the repo's name.

**Status:** 0.1, the daily delivery loop: setup, shipping, Live writes, monitoring, live verification and session close-out. The rest of the workflow skills and subagents land in 0.2. Changes are in [CHANGELOG.md](CHANGELOG.md).

## Install

### 1. Base layer (required)

The Harness calls Matt Pocock's skills by name instead of copying them. Install them from his own marketplace so you track his main branch:

```
claude plugin marketplace add mattpocock/skills
claude plugin install mattpocock-skills@mattpocock
```

If you already have them from another marketplace (for example the official one, which can lag behind), uninstall that copy first so the two don't shadow each other.

Repos set up with an older Base layer need a rename first: see [Upgrade notes](#upgrade-notes).

### 2. The Harness

```
claude plugin marketplace add nathan-scheele/claude-harness
claude plugin install harness@harness
```

### 3. Sign in to the Harness browser (once)

The Harness ships its own browser server, the Harness browser: [chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) 1.10.1 running Chrome with a dedicated, persistent profile kept in the plugin's data directory (under `~/.claude/plugins/data/`). It is separate from your everyday Chrome, survives plugin updates and is deleted when you uninstall the plugin. It needs Node.js and Chrome.

Sign it in to the accounts verification needs (your app's dev and live sites, vendor dashboards) once:

1. In a Claude Code session with the Harness installed, ask: "Open https://dev.example.com/login in the Harness browser" (with your own sign-in URL).
2. Sign in in the Chrome window that opens. Repeat for each account.

Sign-ins persist in the profile. If one expires, `harness:live-verifier` lists signing in again as a step for you instead of failing the check.

Pages always open in the background (a hook denies any other kind), so the browser doesn't take your focus once it's running (Chrome shows its own window the first time a session uses it). The profile can be open in only one Chrome at a time: if another session is already using the Harness browser, live-verifier reports it as blocked rather than taking that browser over.

## Upgrade notes

To update both plugins, run these, then restart Claude Code:

```
claude plugin marketplace update
claude plugin update harness@harness
claude plugin update mattpocock-skills@mattpocock
```

- **From 0.1.0: rename `CONTEXT.md` to `GLOSSARY.md`.** This comes from the Base layer, not a Harness change: its current versions name the per-repo domain doc `GLOSSARY.md` instead of `CONTEXT.md`. In repos set up with an older Base layer, rename `CONTEXT.md` to `GLOSSARY.md` (and any `CONTEXT-MAP.md` to `GLOSSARY-MAP.md`) so its skills find it.

## What's in it

| Skill | What it does |
| --- | --- |
| `harness:standards` | The 14 Standards (S1-S14) every Harness skill and subagent follows: Live-write gate, pre-authorized checks, live system as truth, structured decisions, deep links, proactive status, scope discipline, cleanup, isolation, browser etiquette, short and plain output, nothing left loose, one-line commands, off-by-default changes. Model-invoked as a reference. |
| `harness:close-session` | Ends a session cleanly: checks every piece of work is landed (squash merges proved by content) or recorded in an issue, PR or memory, stops what the session started, removes its worktree, then gives a safe-to-clear verdict and a paste-ready priming prompt for the next session. After a session that struggled, it names the moments and suggests the Base layer's `/retro` before you clear. Never merges, deploys, deletes remote branches, closes PRs or drops other sessions' stashes. |
| `harness:setup-harness` | Writes the repo's Project config (`docs/agents/harness.md`): detects code host, repo slug, default branch, CI workflows and pre-flight commands, asks only for the rest, previews, then writes. Other Harness skills read it instead of guessing. Run once per repo. |
| `harness:gated-write` | Runs a production data write through the Live-write procedure: read-only fact pass, change table posted to chat and the issue, a stop for explicit approval, dry run, canary of 1-3 records, operator spot-check, full run with progress, re-check against the live system, and a rollback ledger (CSV of before/after values) posted on the issue. Reads data connectors and dev/sandbox targets from Project config; dev and sandbox writes skip the gate. |
| `harness:run-monitor` | Watches a CI run, deploy or long job from the main session: polls at an interval you set and posts a status line each time, checks the outcome against what was expected (jobs listed in Project config, counts, side effects) before calling it done, and on failure has a subagent find the first failing step and say whether it's a real defect or a reporting artifact. Reads only: it offers to file an issue for a real defect and files one only on your yes. |
| `harness:ship-and-land` | Takes an implemented issue from a committed branch to verified production when you say "ship it": runs the Project config pre-flight checks, opens a PR that closes the issue (body from the Base layer's `pr` skill when it's installed), diagnoses failing or missing CI checks (real failure, flake, checks that never fired), stops for your explicit go-ahead before a merge that deploys, merges, watches CI and the deploy with run-monitor's interval status, hands off to live-verifier, closes the issue if the merge didn't, then runs close-session. Doesn't review the code again; GitHub only in v1, with every host command in one section. |
| `harness:issue-prompts` | Prepares Lanes for parallel work you steer per session (the alternative to the Base layer's `implement-spec`): finds the issues that are unblocked now (native blocked-by links and `## Blocked by` lists), writes one self-contained prompt per issue under `.lanes/<group>/` (kept out of git) (spec and ADRs to read, verified code to reuse, sibling Lanes and their overlap, a hard gate for Live writes, your Pre-flight commands from Project config) and replies with one-line `claude -w` launch commands, each in its own worktree. Opens each prompt with the Base layer's `implement`, or spells out its steps when that isn't installed. Doesn't start the sessions. |
| `harness:audit-and-apply` | Audits every consumer (records in a live system, or files in a repo) against a checklist when you say "audit every X and fix what's safe" or "make B match A": agrees scope and checklist, enumerates every consumer into a list file under `.audit/` (kept out of git), classifies each finding safe / risky / skip with a reason in a table posted to the audit issue, and recommends. Applies only the safe set, through gated-write for data or one chore PR for code (left open for you to merge), re-checks the whole scope afterwards and reports anything unmatched, then files one issue for the remainder. Asking for the audit doesn't approve its writes. |
| `harness:live-verifier` (subagent) | Checks a change on a dev or live target (from the Project config) against the acceptance criteria of an issue or PR, in the Harness browser and with read-only API calls, and returns a pass/fail table. Sets up and resets fixtures on dev targets only, lists the steps only you can do (a sign-in) and waits for them. Read-only by construction: no file-editing tools, and a hook limits its Bash to reads. |
| `harness:data-digest` (subagent) | Pulls large datasets through the data connectors in the Project config (MCP servers or CLIs) and local exports, and returns compact tables (50 rows or fewer), the exact method and whether the sweep was complete or partial, so raw data never enters your main context. Saves a full extract only to a path you give. Strictly read-only: a hook limits its Bash to reads, its MCP calls to the connectors' reads and its writes to a new extract file; a write you ask for comes back as a prepared payload for gated-write. |

Vocabulary (Harness, Base layer, Live write, Project config and the rest) is defined in [GLOSSARY.md](GLOSSARY.md); design decisions are in [docs/adr](docs/adr).

## Development

Layout: the marketplace manifest is at `.claude-plugin/marketplace.json`; the plugin itself is in `plugin/`.

```
claude plugin validate --strict .        # marketplace
claude plugin validate --strict plugin   # plugin
scripts/test-leak-check.sh               # leak-check tests
scripts/test-setup-detect.sh             # setup-harness detector tests
scripts/test-fake-gh.sh                  # fake gh used by eval fixtures (plugin/evals/fakes)
scripts/test-eval-tools.sh               # eval trace saving and the offline grader checker (needs jq, node)
scripts/test-guard.sh                    # hook tests: read-only live-verifier and data-digest, background pages (needs node)
scripts/test-release-check.sh            # release-check tests
scripts/release-check.sh . v0.1.0        # before tagging: plugin version is the newest CHANGELOG entry and matches the tag
scripts/leak-check.sh .                  # fail on emails, home paths, store domains, theme IDs, account subdomains, chat and resource IDs
scripts/run-evals.sh --case <name>       # behavioural evals vs a no-plugin baseline (uses your Claude credentials); saves traces
scripts/check-graders.mjs <case>         # re-grade a case's saved traces offline
```

CI runs strict validation, the leak check and the release check (without a tag) on every push and PR. Private identifiers the leak check must catch but this public repo must not contain (a work domain, a store name) go in the `LEAK_PATTERNS` repository secret, one extended regex per line.

Evals live in `plugin/evals/<case>/`: each case builds a fixture repo, runs with the plugin and without it, and `run-evals.sh` fails unless every case passes and the plugin beats the baseline. Writing a case or grader, and debugging a failed run: [plugin/evals/README.md](plugin/evals/README.md).

## Credits

The reviewer-subagent structure is borrowed from [claude-code-ultimate-guide](https://github.com/FlorianBruniaux/claude-code-ultimate-guide).

## License

[MIT](LICENSE)
