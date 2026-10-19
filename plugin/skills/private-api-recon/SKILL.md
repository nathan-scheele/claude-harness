---
name: private-api-recon
description: "Automate a web app that has no public API: walk the capability ladder (official API, MCP server, network capture in the signed-in Harness browser, manual), find the endpoints and identifiers from the network calls behind a known example, document them with their limits, and build a small list/create/delete CLI with a dry-run flag and the token from the environment. Its creates and deletes run dry run, one item, then the rest, through harness:gated-write. Use when the operator says an app has no API, asks to automate it anyway, to use its hidden or internal API, or to watch the network requests in their signed-in browser."
---

# Private API recon

Goal: a job the operator would otherwise click through by hand runs from a small CLI grounded in the app's real network calls, and nothing is written to the app until the operator has seen exactly what will change.

Load `harness:standards` first (Skill tool) and follow it throughout, especially S1 Live-write gate, S2 pre-authorized checks, S3 live system is truth, S4 structured decisions, S5 deep links, S10 browser etiquette and S13 one-line commands. If it isn't available, carry on with the steps below.

## 1. Read Project config

Read `docs/agents/harness.md` by heading and key:

- `## Data connectors`: whether this system already has a connector.
- `## Dev and sandbox`: whether the app has a target where writes are pre-authorized.
- `## Issues`: **Tracker**, for the change table later.

A missing file or section, or an `unset` value, means stop and point the operator at `/harness:setup-harness`.

Done when you can say, in one line each: the app and its URL, the records and operations the job needs (list, create, delete), the items (a file, a list), and the **known example**: one existing record the operator points to by URL. Ask for the example if there is none; recon is grounded in it.

## 2. Walk the capability ladder

State the ladder to the operator in this order, then try each rung until one covers the job:

1. **Official API**: a `## Data connectors` entry for the system, or a public API in the vendor's developer docs (search them) that covers these operations.
2. **MCP server**: a server in this session for the system (ToolSearch the app's name) whose tools cover the operations.
3. **Network capture**: the private API the app's own web client calls, read from the signed-in Harness browser (steps 3-7).
4. **Manual**: a checklist of Human steps for the operator, when capture finds no usable endpoints, the token can't be reproduced outside the browser, or the vendor's terms forbid automated access.

A rung the operator has ruled out ("no public API") still gets its quick check; a rung you can't check (no network, no search) is recorded as unchecked. If rung 1 or 2 covers the job, stop here and use it: add it under `## Data connectors` if it isn't there, and run its writes through `harness:gated-write`.

Done when all four rungs have a one-line outcome: each rung above the one you use with its evidence (a docs link, the tools you searched for), the one you use, and each rung below it as the fallback.

## 3. Capture the known example

In the Harness browser (S10):

- Call `list_pages` first; pages you didn't open belong to someone else and stay untouched.
- Open the known example with `new_page` and `background: true`, then its list page (where records are listed and paged).
- On a sign-in screen, stop with a Human step (step 6) to sign the Harness browser in; never type credentials.
- `list_network_requests` with `resourceTypes: ["fetch", "xhr"]`, then `get_network_request` on the few calls whose URL or response carries the example's id or name. From each, note:
  - method, URL, query and pagination parameters, request body, response shape;
  - **identifiers**: the record id's format, and any account or workspace id in the path, query or headers;
  - **auth**: which header or cookie carries the operator's session, by name only;
  - **required headers**: Origin, Referer, CSRF or account headers the API checks (a CORS `access-control-allow-origin` naming the app's origin means send Origin and Referer as the app does);
  - **limits**: rate-limit headers, page size caps, payload limits.
- **Write endpoints** (create, delete) come from reads: search the app's own JavaScript bundle (`evaluate_script`, fetching the script URL from the network list with GET) for the paths the reads use, and record each write as unconfirmed until its first real run. The UI's Save and Delete buttons are Live writes on the operator's data, so the capture stays on pages that only read. If the bundle doesn't give a write's path or body, record the gap and put the way forward to the operator as a decision (S4).
- Close the pages you opened.

The session token is the operator's secret. Record where it lives (header or cookie name, and where in the app the operator can copy it), and keep its value out of everything you write: files, commands, chat, issue comments, memory.

Done when list, create and delete each have a method and path (create and delete confirmed or marked unconfirmed), and the auth, required headers, identifiers and limits are noted.

## 4. Document the endpoints

Write `scripts/<app>/ENDPOINTS.md` in the target repo (`<app>` is a short lowercase slug of the app's name):

- **Source**: captured from the Harness browser on <date>, on the known example (its URL).
- **Base URL**, **auth** (scheme, header or cookie name, where the operator copies the token; never the value) and **required headers**.
- **Endpoints**: a table of method, path, purpose, request body, and how it is known (`captured on <example>`, `from the app bundle, unconfirmed`, `confirmed by the one-item run on <date>`).
- **Identifiers**: id formats, and which id each endpoint takes.
- **Limits**: rate limit and window, page size, payload caps, and quirks (a write response that echoes the old value, eventual consistency), each with where you saw it.

## 5. Build the CLI

Copy [cli.sh](cli.sh) to `scripts/<app>/<app>` and make it executable. It is a Bash and curl script, so it runs wherever the repo runs, in any stack, with nothing to install. Edit its `Set from ENDPOINTS.md` block: base URL, the app's origin, the token's variable name (`<APP>_TOKEN`), the auth header, other headers the API checks (an account id, never a secret), and the list, create and delete paths. If the list call is paged, add the paging loop to `list`, keeping to Bash and curl. It already has:

- `list`, `create <items.jsonl>` (one JSON request body per line) and `delete <id>...`;
- `--dry-run`, which prints every request and stops before reading the token or calling curl; an unknown flag aborts, so a mistyped dry run never writes;
- `--offset N` and `--limit N`, so one item goes first and the rest after;
- the token from `<APP>_TOKEN` or a `.env` line beside the CLI, sent on curl's stdin, never printed.

Then:

1. Add `scripts/<app>/.env` to `.gitignore`.
2. Turn the operator's items into `scripts/<app>/<job>.jsonl` (one request body per item, the fields the captured create uses).
3. Check: `bash -n scripts/<app>/<app>`, then the dry runs, `scripts/<app>/<app> create <job>.jsonl --dry-run` (and `delete <ids> --dry-run` when the job deletes). These check that the CLI builds the right requests; this CLI's dry run never reaches the app, so it is pre-authorized, unlike the connector dry runs gated-write holds back until approval. The counts and a sample request go in the report.
4. Add the CLI to Project config under `## Data connectors`, so gated-write and data-digest can use it:
   `- **<App>**: CLI \`scripts/<app>/<app>\`; read-write; reads: \`list\``

Done when the dry runs print one request per item with the expected count.

## 6. Hand over the token

The CLI needs the operator's token, and copying it is a Human step. List every Human step at once, each as:

```
1. <what the operator does> - <deep link> - then: <the end state you will check>
```

For the token: copy it from where `ENDPOINTS.md` says (a link to that page of the app), into `scripts/<app>/.env` as `<APP>_TOKEN=...`. The end state: `scripts/<app>/<app> list` returns the known example. They put it in the file themselves, never in the chat. Then stop and wait for "done".

## 7. Prove a read

Run `scripts/<app>/<app> list` and find the known example in it with the same fields the app shows (S3). A 401 or 403 means the auth header, Origin or Referer differs from the captured call: compare and fix the CLI before asking the operator for anything. A token that expires mid-run is another Human step.

Done when `list` returns the known example as the app shows it.

## 8. Dry run, one, then the rest

Creates and deletes on the app are Live writes unless the app is listed under `## Dev and sandbox`. Run them through `harness:gated-write` with this CLI as the connector, and tell it the canary is exactly one item (an endpoint that has never been called from outside the browser is unproven). For creates (`create <job>.jsonl`) and deletes (`delete <ids>`) alike:

1. **Dry run**: the command with `--dry-run`.
2. **One item**: the command with `--limit 1`, then `list` to confirm it, with the record's link in the app (S5).
3. **The rest**: the command with `--offset 1`, then `list` to re-check every item.

The rollback ledger (gated-write step 10) for these: a create has no id until it is written, so its row (`<new id>,record,absent,created`) goes in as soon as the id comes back, and undoing it is `delete <id>`. A delete's row holds the whole record from `list` as `before`, so it can be created again.

Before the operator's go-ahead for a write, `list` is the only call that reaches the app (S1, ADR 0008). A request to automate the job is not a go-ahead for its writes. After the one-item run, update `ENDPOINTS.md`: mark the write confirmed, and add any quirk it showed.

## Report

End with one short report in exactly this shape, every line present, even when you explain things in prose around it. The operator reads the Ladder line to see what was tried before the private API, so it names all four rungs in order:

```
Ladder: official API - <outcome>; MCP - <outcome>; network capture - <used | outcome>; manual (Human steps) - <fallback | used, why>
Endpoints: <path to ENDPOINTS.md>; list <METHOD path>, create <METHOD path>, delete <METHOD path> (<confirmed | unconfirmed>)
Limits: <rate limit, page size, other>
CLI: <path>; dry run: <n> would be created (or deleted)
Human steps:
1. <what> - <deep link> - then: <end state you will check>
Next: dry run, then 1 item, then the remaining <n>, through gated-write, each after your go-ahead
```
