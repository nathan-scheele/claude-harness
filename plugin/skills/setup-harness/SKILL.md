---
name: setup-harness
description: Set up this repo for the Harness by writing its Project config (docs/agents/harness.md), the values Harness skills read instead of guessing (code host and repo slug, default branch, pre-flight commands, CI workflows and jobs, merge method and whether merging deploys, deploy target and live URL, dev/sandbox targets, fixtures, data connectors, issue-close convention). Use when the operator asks to set up or configure the harness, when a Harness skill reports the Project config is missing or a value is unset, or to refresh the config after the repo changes. Detects what it can, asks only for the rest, previews, then writes.
---

# Set up the Harness

Write this repo's Project config: the single document `docs/agents/harness.md` that Harness skills read for repo-specific values. It sits beside the Base layer's `docs/agents/*.md` files and follows their style.

First load the Standards skill (`harness:standards`) through the Skill tool. Asking follows S4, values follow S3, and this skill's only write is the Project config file: no commits, pushes or Live writes.

## Process

### 1. Detect

Run the detector; it is read-only and prints `key=value` lines (empty value = not detected):

```
bash "${CLAUDE_SKILL_DIR}/detect.sh"
```

It covers code host, repo slug, default branch, GitHub Actions workflows with their job ids, pre-flight commands from `package.json` scripts and Makefile targets, and whether a Project config already exists. Then fill in what you can from the repo yourself (S2, read-only):

- **Existing config.** If `existing_config` is set, read it. Its values are the starting point; this run updates that file, never a second one.
- **GitHub settings.** If the host is GitHub and `gh` works, `gh repo view <repo> --json defaultBranchRef,squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed` fills the default branch, and the merge method when exactly one method is allowed. If `gh` fails, carry on; those values become questions.
- **Workflow files.** Read them to spot a deploy workflow (runs on push to the default branch and deploys) and so whether merging deploys.
- **Other checks.** Standard check commands for other ecosystems in the repo (e.g. `cargo test`, `go test ./...`) are pre-flight candidates.
- **Connectors and fixtures.** `.mcp.json` servers are data-connector candidates; fixture or seed directories and reset scripts are fixture-convention candidates.

Keep two kinds of value apart: **detected** (read straight from the repo or host) and **inferred** (your reading of it, such as "deploy.yml deploys on merge"). Both appear in the preview for confirmation; neither is written without it.

### 2. Ask only for what's missing

Every section of [project-config.md](project-config.md) needs a value or `none`. List what is still unknown after step 1 and ask for exactly those, never for a value you detected. Lead with a short summary of what you detected, one line per value, so the operator sees why those aren't asked.

Ask per S4, grouping related values (up to four questions per AskUserQuestion call). The recommended option is the likely answer where one exists (the current branch as default branch, `Closes #<n>` as the close convention on GitHub); offer an explicit `none` wherever the repo may genuinely have none. If the operator doesn't know a value, record it as `unset`.

If the host is not GitHub, record it as found and say once that Harness shipping skills support GitHub only in v1.

### 3. Preview

Show the complete document exactly as it will be written, in one fenced markdown block, using the section names and order of [project-config.md](project-config.md) and its `**Key**: value` lines. Below it, list what came from where (detected, inferred, answered) and, on a re-run, what changed from the existing file.

Then ask whether to write it (S4: "Write it" recommended, or "Change something"), and stop. Apply corrections and preview again until the operator confirms. If the operator's request already said to write once shown, and nothing is still unknown or inferred-but-unconfirmed, show the preview and write without stopping.

### 4. Write

Write the whole previewed document to `docs/agents/harness.md` in one Write tool call (create `docs/agents/` if needed), even on a re-run that changes one line: not piecemeal Edits, so the file is exactly what the operator confirmed.

- One file, every section once, in template order. A re-run replaces values in place; it never appends a second copy of a section or creates another config file.
- Keep anything the operator added that the template doesn't have (extra notes, extra keys) where it was.
- Use `none` for things the repo doesn't have and `unset` for values the operator couldn't give. Never leave a key out.

### 5. Done

Say it's written and link the file (S5). List any `unset` values: Harness skills that need them will stop and ask until they're filled in. The file is the operator's to commit.

The rules for reading the file live in the Standards skill's Project config entry and in the document's own preamble, so other skills get them without loading this one.
