# Claude Harness

A public Claude Code plugin of subagents and skills distilled from one operator's day-to-day work, layered on top of Matt Pocock's skills.

## Language

**Harness**:
This repo's Claude Code plugin, installed as `harness` (slash namespace `harness:`): the set of subagents, skills, hooks and MCP config installed together.
_Avoid_: toolkit, kit, framework

**Base layer**:
Matt Pocock's skills plugin, which the Harness requires to be installed and calls by name rather than copying.
_Avoid_: Matt's harness, upstream skills

**Project-local item**:
A customization that encodes one repo's conventions (knowledge skills, rules, CLAUDE.md, scaffold commands) and stays in that repo, outside the Harness.
_Avoid_: repo skill, local harness

**Project config**:
The single per-repo document `docs/agents/harness.md`, written by the setup skill, that holds the values the Harness reads in that repo (repo slug, CI job names, deploy URL, dev targets, fixtures).
_Avoid_: settings, harness config

**Data connector**:
An MCP server or CLI listed in the Project config's `## Data connectors` through which Harness skills and subagents read a system's data in bulk or write to it, marked read-only or read-write, with the reads a read-only subagent may use.
_Avoid_: data source, integration

**Live write**:
An action that changes something real people or production depend on (a merge or push that deploys, a production data write, an outbound message someone else will read), and so needs the operator's explicit go-ahead for that specific action. Writes to dev, sandbox or preview environments and the operator's own issue tracker are not Live writes.
_Avoid_: prod change, destructive action, risky write

**Pre-authorized**:
An action the agent takes without asking: read-only checks on any system, and writes to dev, sandbox or preview environments or the operator's own issue tracker. The complement of a Live write.
_Avoid_: safe action, allowed action

**Lane**:
One issue implemented in its own Claude session and git worktree, launched from a prompt file, so the operator can steer it independently.
_Avoid_: worker, swarm pane, parallel session

**Human step**:
An action only the operator can perform (a login, a click in a vendor dashboard, a command needing their credentials), handed over with a deep link and confirmed afterwards by re-reading live state.
_Avoid_: manual step, TODO for user

**Standard**:
A rule of conduct every Harness skill and subagent follows, distilled from corrections the operator kept repeating (e.g. approval before live writes, live system as ground truth).
_Avoid_: rule, guideline, preference

**Standards skill**:
The one reference skill that holds every Standard; other Harness skills and subagents pull it in instead of restating Standards.
_Avoid_: style guide, conventions doc

**Harness browser**:
The browser server the Harness ships for its subagents, using a dedicated persistent signed-in profile separate from the user's everyday browser.
_Avoid_: signed-in Chrome, devtools browser
