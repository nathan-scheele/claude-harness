---
name: stakeholder-message
description: "Draft a self-contained Slack, chat or email message to a stakeholder or a vendor's support from the current state of the work, limited to what the recipient owns, in tight, medium and full versions, plain text for chat tools. Applies edits ('tighter', 'drop X', 'update with the latest') by redrafting from the latest state without re-explaining. Vendor-escalation mode checks for a known issue, assembles evidence (trimmed network capture, screenshots, IDs) from the Harness browser and drafts counter-replies to the vendor. Never sends or posts anything: sending is the operator's. Use when the operator says 'draft a Slack/email to X about this', 'write up a message to support', 'what do I tell the rep', or pastes a vendor's reply, and for every change to a message draft, including one pasted from earlier ('make it tighter', 'shorter', 'drop the part about X', 'doesn't sound like AI')."
---

# Stakeholder message

Goal: a message the operator can paste and send as is: right for its channel, true to the current state, about only what the recipient owns, and never sent by the agent.

Load `harness:standards` first (Skill tool) and follow it throughout, especially S1 Live-write gate, S3 live system is truth, S5 deep links, S7 scope discipline, S10 browser etiquette and S11 short and plain. If it isn't available, carry on with the steps below.

## Never send

A message someone else will read is a Live write, and this skill never makes it. Don't send, post, schedule or save it anywhere outside this conversation: no chat, email or support CLI or MCP tool, no typing into a chat widget in the browser, no draft saved in someone's mailbox or workspace. "Send it", "post it to #channel" or a later "yes, send" is a request for the draft, not a go-ahead (ADR 0008): give the draft and say it hasn't been sent and that sending it is the operator's. That holds whether or not a send tool is at hand; say "sending is yours", not "I can't".

Drafts live in the reply only. Write a file only for vendor evidence (step 6), or when the operator asks for one.

## 1. Channel and limits

Infer them from the request and its context; ask only if the recipient or topic is unclear.

- **Chat tool** (Slack, Teams, a support chat widget, SMS): plain text, never markdown. Short paragraphs; a plain hyphen list at most; links as bare URLs.
- **Email**: a `Subject:` line, then a plain-text body, unless the operator asks for HTML.
- **Limits**: a character limit the operator or the tool states (support widgets often cap at 500-2000 characters). Keep every version under it.
- **Unknown channel**: assume chat and say so in one line.

Channel and limits come from the request, not Project config. If `docs/agents/harness.md` exists, its `## Issues` and `## Code host` say where the issue tracker and PRs live; a missing Project config is not a stop for this skill.

## 2. Facts from the current state

Re-read the primary sources every time you draft, redrafts included (S3): the issue and its comments, the PR and CI state, the live system (read-only checks, S2). Earlier chat output and an earlier draft are not sources. If a source contradicts what the conversation or an earlier draft said, trust the source and say so in one line outside the draft.

Sort the facts into done, in progress, open decisions and not started. Keep only what the recipient owns, asked about or has to act on. Leave out side findings, internal tidy-ups, dependency bumps, tooling and other teams' problems (S7). If you can't tell whether something is theirs, leave it out and mention it in one line outside the draft.

Put only verified facts in the draft as facts; say plainly what is an assumption or still unknown.

## 3. Write it self-contained

The recipient may not have seen any earlier report. Name the thing, then say what happened, where it stands and what is needed from whom, without pointing at "the above" or at earlier output.

- Plain voice, short sentences, no filler or sign-off padding. It shouldn't read as AI-written: no headings or bolded labels in chat, no emoji runs.
- Longer versions use neutral section names: "Done", "In progress", "Open decisions", "Not started". Not "What we need from you".
- One link or ID per thing the recipient might look up (S5): a bare URL in chat.

## 4. Three lengths

Give three versions, in this order, each under a label line:

- **Tight**: one to three sentences: where it stands and the one thing needed.
- **Medium**: four to eight lines: adds what's done and the open decisions.
- **Full**: everything the recipient owns, with neutral section names.

When the draft is for a chat tool, the whole reply is plain text, not only the drafts, so any part of it can be pasted as is: labels as plain words ending in a colon, and no bold, headings, backticks, tables or markdown links anywhere. Layout:

```
<at most one line the operator needs first: a source that contradicted the conversation, something left out on purpose, an assumed channel>

Tight:
<draft>

Medium:
<draft>

Full:
<draft>

Not sent: sending is yours. Paste the one you want into <channel>.
```

For an email, each version starts with its own `Subject:` line.

## 5. Edits

"Tighter", "drop the part about X", "rename that section", "update with the latest", for a draft of yours or one the operator pastes: re-read the sources (step 2), apply the edit, and reply with only the reworked draft, in the same layout rules, ending with the not-sent line. "Tighter" means at least a third shorter: keep where it stands and what is needed, and cut the background to one clause.

If the state has changed since the earlier draft, redraft from the new state. The reply is exactly this, and nothing else:

```
Updated: <what changed since the earlier draft, in one sentence of 15 words or fewer; leave this line out if nothing did>

<the reworked draft>

Not sent: sending is yours.
```

Don't re-explain the background, the state or what you changed beyond that one sentence, and don't offer three versions again unless asked.

## 6. Vendor escalation

Use this mode when the recipient is a vendor's support (a rep in a chat, a support ticket, a support email).

1. **Known-issue check.** Look at the vendor's status page, docs or changelog, community forum and public issue tracker, in the Harness browser or by fetching them. Link what you find (S5). Keep verified facts apart from assumptions.
2. **Summary.** Symptom, when it started (with time zone), how to reproduce it, who or what is affected, and what is already ruled out.
3. **Evidence.** Gather it read-only in the Harness browser (S10). Open each page you need with `new_page` in the background, select it before acting, and never navigate, reload or type into a page the operator already has open, such as their support chat.
   - **Network capture**: `list_network_requests` on the page where it fails, then `get_network_request` for each failing request. Save a trimmed capture as a `.har` file with Write: only the failing requests and the ones just before them, with `Authorization`, `Cookie`, `Set-Cookie`, API keys, tokens and session IDs replaced by `[redacted]`, and response bodies cut to the part that shows the error, under the vendor's upload limit (1 MB if unknown).
   - **Screenshot**: `take_screenshot` of the failure, with `filePath` in the evidence folder.
   - **IDs**: request, trace or correlation IDs, error codes, account, order or ticket IDs, timestamps with time zone, and the browser and version.

   The evidence folder is the path the operator names, else `escalation/<vendor>-<YYYY-MM-DD>/` at the repo root, added to `.git/info/exclude` so captured traffic is never committed. List each file's path in the reply. Never put a secret in a draft or a file.
4. **Draft** in the channel's format (step 1; a support chat is a chat tool): what is happening, the IDs inline, the files to attach, the matching known issue if there is one, and one clear ask (confirm it's the same incident, give an ETA, escalate).
5. **Counter-reply.** When the operator pastes the vendor's reply, judge it in one or two lines outside the draft: does it answer, is it boilerplate, or does it ask for a diagnostic step? If it asks for something already ruled out or contradicted by the evidence, the counter-reply says so politely and points at the evidence. If it asks for a new diagnostic step, do what you can yourself first (re-test, re-capture), and list the steps only the operator can do. Then draft the counter-reply in three lengths (step 4).
6. **After the vendor or the operator acts**, re-check the live state (S3) and say what changed.
