#!/usr/bin/env bash
# CLI over a web app's private API, built by harness:private-api-recon.
# Endpoints, auth and limits: ENDPOINTS.md beside this file.
#
#   <cli> list
#   <cli> create <items.jsonl> [--offset N] [--limit N] [--dry-run]
#   <cli> delete <id>... [--offset N] [--limit N] [--dry-run]
#
# create sends one request per line of <items.jsonl>, each line a JSON request
# body; delete sends one per id. --offset skips the first N items and --limit
# sends at most N, so one item can go first and the rest after. --dry-run
# prints every request and sends nothing: it stops before reading the token or
# calling curl. list is a read and always sends. A request that fails stops the run.
#
# Token: the TOKEN_VAR environment variable, else a TOKEN_VAR=... line in .env
# beside this file (git-ignored). It is sent on curl's stdin, never on its
# command line, and never printed.
set -euo pipefail

# --- Set from ENDPOINTS.md ---
BASE=https://api.example.com              # API base URL
ORIGIN=https://app.example.com            # the web app's origin, sent as Origin and Referer
TOKEN_VAR=EXAMPLE_TOKEN                   # where the operator's token is read from
AUTH='authorization: Bearer {token}'      # the header that carries it, e.g. 'cookie: session={token}'
HEADERS=()                                # other headers the API checks, e.g. ('x-account: acct_123')
LIST_PATH='/v1/items'
CREATE_PATH='/v1/items'
DELETE_PATH='/v1/items/{id}'
# --- end ---

here="$(cd "$(dirname "$0")" && pwd)"
me="$(basename "$0")"
die() { echo "$me: $*" >&2; exit 1; }

dry=0 offset=0 limit='' args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1 ;;
    --offset)
      [[ "${2:-}" =~ ^[0-9]+$ ]] || die "--offset needs a number"
      offset="$2"; shift ;;
    --limit)
      [[ "${2:-}" =~ ^[1-9][0-9]*$ ]] || die "--limit needs a number of 1 or more"
      limit="$2"; shift ;;
    -*) die "unknown flag $1 (known: --dry-run --offset N --limit N)" ;;
    *) args+=("$1") ;;
  esac
  shift
done
set -- ${args[@]+"${args[@]}"}

# fill TEMPLATE PLACEHOLDER VALUE: TEMPLATE with its first {PLACEHOLDER} replaced by VALUE, taken literally.
fill() { printf '%s%s%s' "${1%%\{$2\}*}" "$3" "${1#*\{$2\}}"; }

token() {
  local t="${!TOKEN_VAR:-}"
  if [ -z "$t" ] && [ -f "$here/.env" ]; then
    t="$(sed -n "s/^$TOKEN_VAR=//p" "$here/.env" | head -n 1 | tr -d '\r')"
    t="${t#[\"\']}"
    t="${t%[\"\']}"
  fi
  [ -n "$t" ] || die "no token: set $TOKEN_VAR, or put $TOKEN_VAR=... in $here/.env (ENDPOINTS.md, Auth, says where to copy it from)"
  printf '%s' "$t"
}

# send METHOD PATH [BODY]: one request; prints the response body.
send() {
  if [ "$dry" = 1 ]; then
    echo "DRY RUN $1 $BASE$2${3:+ $3}"
    return
  fi
  local t h extra=()
  t="$(token)"
  for h in ${HEADERS[@]+"${HEADERS[@]}"}; do extra+=(-H "$h"); done
  { fill "$AUTH" token "$t"; echo; } |
    curl -sS --fail-with-body -X "$1" "$BASE$2" -H @- \
      -H "origin: $ORIGIN" -H "referer: $ORIGIN/" -H 'accept: application/json' \
      ${extra[@]+"${extra[@]}"} \
      ${3:+-H 'content-type: application/json' --data-binary "$3"} ||
    die "$1 $2 failed; stopped"
  echo
}

# in_window N SENT: whether the Nth item (from 1) goes, given SENT already sent.
in_window() { [ "$1" -gt "$offset" ] && { [ -z "$limit" ] || [ "$2" -lt "$limit" ]; }; }

summary() { # summary COUNT VERB
  if [ "$dry" = 1 ]; then echo "dry run: $1 item(s) would be $2"; else echo "$1 item(s) $2"; fi
}

list() {
  [ "$dry" = 0 ] || die "list is a read and always sends; run it without --dry-run"
  send GET "$LIST_PATH"
}

create() {
  local file="${1:-}" n=0 sent=0 line
  [ -f "$file" ] || die "create: give a JSONL file, one request body per line"
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    n=$((n + 1))
    in_window "$n" "$sent" || continue
    echo "[$n] POST $CREATE_PATH"
    send POST "$CREATE_PATH" "$line" < /dev/null
    sent=$((sent + 1))
  done < "$file"
  summary "$sent" created
}

delete() {
  [ $# -gt 0 ] || die "delete: give one or more ids"
  local n=0 sent=0 id
  for id in "$@"; do
    n=$((n + 1))
    in_window "$n" "$sent" || continue
    send DELETE "$(fill "$DELETE_PATH" id "$id")"
    sent=$((sent + 1))
  done
  summary "$sent" deleted
}

case "${1:-}" in
  list | create | delete) cmd="$1"; shift; "$cmd" "$@" ;;
  *) sed -n '2,8s/^# \{0,1\}//p' "$0" | sed "s/<cli>/$me/" >&2; exit 2 ;;
esac
