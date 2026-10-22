#!/usr/bin/env bash
# Builds the integration-reviewer fixture repo in the current directory: a
# small service that pushes users' plans to an external CRM through a wrapper
# (src/clients/crm.js) that throttles, retries 429s and 5xx with backoff, and
# has a batch method. docs/integrations/crm.md states the CRM's limits: 5
# requests a second, and a batch endpoint for up to 100 contacts a request.
#
# main holds the wrapper and the docs. The branch `push-plans` adds
# src/sync/push-plans.js, in one of two versions:
#   --unbatched  updates one contact per request in a loop (the loop is line
#                8, the call line 9), where the docs say to use the batch
#                endpoint. Graders hold those line numbers.
#   --clean      sends every change through the wrapper's batch method and
#                fails on per-contact errors.
#
# Plain git fails in the eval sandbox on macOS (plugin/evals/fakes/README.md),
# so .tools/git is a git that works there; the case's system prompt names it.
set -euo pipefail

version="${1:?usage: integration-reviewer-repo.sh --unbatched | --clean}"

git init -q -b main
git config user.name fixture
git config user.email fixture@example.com

mkdir -p src/clients src/sync docs/integrations .tools

cat > package.json <<'JSON'
{
  "name": "plans-sync",
  "version": "0.3.0",
  "private": true,
  "scripts": { "test": "node --test" }
}
JSON

cat > README.md <<'MD'
# plans-sync

Keeps each user's plan in step with their contact in the CRM. Every CRM call
goes through `src/clients/crm.js`; the CRM's limits and field mapping are in
`docs/integrations/crm.md`.
MD

cat > docs/integrations/crm.md <<'MD'
# CRM API

Base URL `https://api.crm.example.com/v2`, one token per service
(`CRM_TOKEN`). Call it only through `src/clients/crm.js`, which handles auth,
throttling and retries.

## Limits

- **Rate limit**: 5 requests per second per token. Over it, the API answers
  429 with a `Retry-After` header (seconds).
- **Batch updates**: `PATCH /contacts/batch` updates up to 100 contacts in one
  request (`crm.updateContacts`). Use it whenever more than one contact
  changes; `PATCH /contacts/{id}` (`crm.updateContact`) is for a single
  contact only. A sync of a few thousand users one request at a time takes
  minutes and starves every other service sharing the token.
- **Partial failure**: a batch answers 200 even when some contacts fail; each
  contact's result carries its own `error`.

## Field mapping

| plans-sync (users table) | CRM contact | Notes |
| --- | --- | --- |
| `crmId` | `id` | set when the contact is linked |
| `email` | `email_address` | |
| `plan` | `tier` | same values: `free`, `pro` |
MD

cat > src/clients/crm.js <<'JS'
// The CRM API wrapper. Every CRM call goes through here: auth, a throttle that
// keeps to the API's 5 requests a second, and retries with backoff on 429 and
// 5xx (honouring Retry-After). Limits: docs/integrations/crm.md.
const BASE_URL = "https://api.crm.example.com/v2";
const MIN_INTERVAL_MS = 200; // 5 requests a second
const BATCH_LIMIT = 100; // PATCH /contacts/batch takes up to 100 contacts
const MAX_ATTEMPTS = 5;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

class CrmClient {
  constructor(token) {
    this.token = token;
    this.lastRequestAt = 0;
  }

  async request(method, path, body) {
    for (let attempt = 1; ; attempt++) {
      const wait = this.lastRequestAt + MIN_INTERVAL_MS - Date.now();
      if (wait > 0) await sleep(wait);
      this.lastRequestAt = Date.now();
      const res = await fetch(`${BASE_URL}${path}`, {
        method,
        headers: { Authorization: `Bearer ${this.token}`, "Content-Type": "application/json" },
        body: body === undefined ? undefined : JSON.stringify(body),
      });
      if (res.ok) return res.json();
      const retryable = res.status === 429 || res.status >= 500;
      if (!retryable || attempt === MAX_ATTEMPTS) {
        throw new Error(`CRM ${method} ${path} failed: ${res.status} ${await res.text()}`);
      }
      const retryAfter = Number(res.headers.get("Retry-After"));
      await sleep(retryAfter > 0 ? retryAfter * 1000 : 2 ** attempt * 250);
    }
  }

  // One contact: PATCH /contacts/{id}.
  async updateContact(id, fields) {
    return this.request("PATCH", `/contacts/${encodeURIComponent(id)}`, fields);
  }

  // Many contacts, BATCH_LIMIT per request, in order. Returns one
  // { id, error } per contact; error is null when it was updated.
  async updateContacts(contacts) {
    const results = [];
    for (let i = 0; i < contacts.length; i += BATCH_LIMIT) {
      const chunk = contacts.slice(i, i + BATCH_LIMIT);
      const { results: chunkResults } = await this.request("PATCH", "/contacts/batch", { contacts: chunk });
      results.push(...chunkResults);
    }
    return results;
  }
}

module.exports = { CrmClient, BATCH_LIMIT };
JS

cat > src/db.js <<'JS'
// The users table. listChangedUsers returns users linked to a CRM contact
// (crmId set) whose plan changed since the given time.
const users = [];

async function listChangedUsers(since) {
  return users.filter((u) => u.crmId && u.planChangedAt >= since);
}

module.exports = { listChangedUsers, users };
JS

git add -A
git commit -qm "CRM wrapper and docs"

git switch -q -c push-plans
if [ "$version" = --unbatched ]; then
  cat > src/sync/push-plans.js <<'JS'
// Pushes plan changes since the last sync to each user's CRM contact.
const { CrmClient } = require("../clients/crm");
const { listChangedUsers } = require("../db");

async function pushPlans(since) {
  const crm = new CrmClient(process.env.CRM_TOKEN);
  const users = await listChangedUsers(since);
  for (const user of users) {
    await crm.updateContact(user.crmId, { tier: user.plan });
  }
  return users.length;
}

module.exports = { pushPlans };
JS
else
  cat > src/sync/push-plans.js <<'JS'
// Pushes plan changes since the last sync to each user's CRM contact.
const { CrmClient } = require("../clients/crm");
const { listChangedUsers } = require("../db");

async function pushPlans(since) {
  const crm = new CrmClient(process.env.CRM_TOKEN);
  const users = await listChangedUsers(since);
  if (users.length === 0) return 0;
  // Maps users.crmId -> contact id and users.plan -> contact tier (docs/integrations/crm.md).
  const results = await crm.updateContacts(users.map((u) => ({ id: u.crmId, tier: u.plan })));
  const failed = results.filter((r) => r.error);
  if (failed.length > 0) {
    const detail = failed.map((r) => `${r.id}: ${r.error}`).join("; ");
    throw new Error(`CRM rejected ${failed.length} of ${users.length} plan updates: ${detail}`);
  }
  return users.length;
}

module.exports = { pushPlans };
JS
fi
git add -A
git commit -qm "Push plan changes to the CRM"

# A git that works in the eval sandbox (see the header).
bash "$(dirname "${BASH_SOURCE[0]}")/sandbox-git.sh" .tools/git
echo .tools/ >> .git/info/exclude
