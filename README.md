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

Vocabulary (Harness, Base layer, Live write, Project config and the rest) is defined in [GLOSSARY.md](GLOSSARY.md); design decisions are in [docs/adr](docs/adr).

## Development

Layout: the marketplace manifest is at `.claude-plugin/marketplace.json`; the plugin itself is in `plugin/`.

```
claude plugin validate --strict .        # marketplace
claude plugin validate --strict plugin   # plugin
scripts/test-leak-check.sh               # leak-check tests
scripts/leak-check.sh .                  # fail on emails, home paths, store domains, theme IDs, account subdomains, chat and resource IDs
scripts/run-evals.sh                     # behavioural evals vs a no-plugin baseline (uses your Claude credentials)
```

CI runs strict validation and the leak check on every push and PR. Private identifiers the leak check must catch but this public repo must not contain (a work domain, a store name) go in the `LEAK_PATTERNS` repository secret, one extended regex per line.

Evals live in `plugin/evals/<case>/`. Each case builds a fixture repo with its scaffold script and runs once with the plugin and once without; `run-evals.sh` fails unless every case passes and the plugin beats the baseline. Eval runs are headless, so the structured question tool (AskUserQuestion) isn't available in them; cases assert the Standards' headless fallback instead.

## Credits

The reviewer-subagent structure is borrowed from [claude-code-ultimate-guide](https://github.com/FlorianBruniaux/claude-code-ultimate-guide).

## License

[MIT](LICENSE)
