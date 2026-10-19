#!/usr/bin/env bash
# Tests for the CLI template private-api-recon copies into a target repo
# (plugin/skills/private-api-recon/cli.sh). Each case copies it into a
# throwaway directory and runs it under /bin/bash (bash 3.2 on macOS) with a
# fake curl first on PATH that logs its arguments and stdin to calls.log, so
# nothing leaves the machine.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CLI="$HERE/../plugin/skills/private-api-recon/cli.sh"
TOKEN='tok-test&5e1\d9a'
failures=0

# A fresh copy of the CLI in $dir/cli/items, the fake curl in $dir/bin.
setup() {
  dir="$(mktemp -d)"
  mkdir -p "$dir/cli" "$dir/bin"
  cp "$CLI" "$dir/cli/items"
  cat > "$dir/bin/curl" <<'SH'
#!/usr/bin/env bash
# Fake curl: logs "ARGS <argv>" and "STDIN <stdin>", then prints a response.
log="$(dirname "$0")/../calls.log"
printf 'ARGS %s\n' "$*" >> "$log"
if [ ! -t 0 ]; then printf 'STDIN %s\n' "$(cat)" >> "$log"; fi
case "$*" in *"${FAKE_CURL_FAIL:-no-such-url}"*) echo '{"error":"bad request"}'; exit 22 ;; esac
echo '{"id":"item_1"}'
SH
  chmod +x "$dir/bin/curl"
  printf '{"name":"one"}\n{"name":"two two"}\n{"name":"three"}\n' > "$dir/items.jsonl"
}

run() { # run <args>...: runs the CLI with the fake curl; sets out, code
  out="$(cd "$dir" && PATH="$dir/bin:$PATH" /bin/bash cli/items "$@" 2>&1)"
  code=$?
}

calls() { cat "$dir/calls.log" 2>/dev/null; }
sent() { calls | grep -c '^ARGS'; } # requests made
has() { calls | grep -qF -- "$1"; }  # the log holds this literal text

check() { # check <name> <condition result 0/1>
  if [ "$2" -eq 0 ]; then
    echo "ok   - $1"
  else
    echo "FAIL - $1 (exit $code)"
    printf '%s\n' "$out" | sed 's/^/       out: /'
    calls | sed 's/^/       log: /'
    failures=$((failures + 1))
  fi
  rm -rf "$dir"
}

setup
run create items.jsonl --dry-run
[ $code -eq 0 ] && [ ! -e "$dir/calls.log" ] && grep -qF 'DRY RUN POST https://api.example.com/v1/items {"name":"two two"}' <<< "$out" &&
  grep -q 'dry run: 3 item(s) would be created' <<< "$out"
check "create --dry-run prints every request, sends nothing, needs no token" $?

setup
run delete a1 b2 --dry-run
[ $code -eq 0 ] && [ ! -e "$dir/calls.log" ] && grep -q 'DRY RUN DELETE https://api.example.com/v1/items/b2' <<< "$out"
check "delete --dry-run sends nothing" $?

setup
run create items.jsonl --dryrun
[ $code -ne 0 ] && [ ! -e "$dir/calls.log" ] && grep -q 'unknown flag --dryrun' <<< "$out"
check "a mistyped dry-run flag aborts before any request" $?

setup
run create items.jsonl --limit 0
[ $code -ne 0 ] && [ ! -e "$dir/calls.log" ]
check "--limit 0 aborts instead of sending everything" $?

setup
run create items.jsonl
[ $code -ne 0 ] && [ ! -e "$dir/calls.log" ] && grep -q 'no token: set EXAMPLE_TOKEN' <<< "$out"
check "no token: a real run stops before any request" $?

setup
export EXAMPLE_TOKEN="$TOKEN"
run create items.jsonl --limit 1
unset EXAMPLE_TOKEN
[ $code -eq 0 ] && [ "$(sent)" -eq 1 ] && has '-X POST https://api.example.com/v1/items' && has '--data-binary {"name":"one"}' &&
  has "STDIN authorization: Bearer $TOKEN" && grep -q '^1 item(s) created' <<< "$out"
check "--limit 1 sends only the first item, token from the environment on stdin, as typed" $?

setup
printf 'EXAMPLE_TOKEN="%s"\r\n' "$TOKEN" > "$dir/cli/.env"
run create items.jsonl --offset 1
[ $code -eq 0 ] && [ "$(sent)" -eq 2 ] && ! has '"one"' && has '{"name":"two two"}' && has '"three"' &&
  calls | grep -qxF "STDIN authorization: Bearer $TOKEN"
check "--offset 1 sends the rest; token from a quoted, CRLF .env line beside the CLI" $?

setup
export EXAMPLE_TOKEN="$TOKEN"
run delete a1 b2 c3 --limit 1
unset EXAMPLE_TOKEN
[ $code -eq 0 ] && [ "$(sent)" -eq 1 ] && has '-X DELETE https://api.example.com/v1/items/a1' && grep -q '^1 item(s) deleted' <<< "$out"
check "delete --limit 1 sends only the first id" $?

setup
sed -i.bak "s/^HEADERS=()/HEADERS=('x-account: acct_123')/" "$dir/cli/items"
export EXAMPLE_TOKEN="$TOKEN"
run list
unset EXAMPLE_TOKEN
[ "$(calls | grep '^ARGS' | grep -cF "$TOKEN")" -eq 0 ] && [ "$(grep -cF "$TOKEN" <<< "$out")" -eq 0 ] &&
  has '-X GET https://api.example.com/v1/items' && has '-H origin: https://app.example.com -H referer: https://app.example.com/' &&
  has '-H x-account: acct_123'
check "list: the token stays off curl's arguments and the output; Origin, Referer and extra headers are sent" $?

setup
export EXAMPLE_TOKEN="$TOKEN" FAKE_CURL_FAIL='"two two"'
run create items.jsonl
unset EXAMPLE_TOKEN FAKE_CURL_FAIL
[ $code -ne 0 ] && [ "$(sent)" -eq 2 ] && ! has '"three"' && grep -q 'failed; stopped' <<< "$out"
check "a failed request stops the run" $?

setup
run list --dry-run
[ $code -ne 0 ] && [ ! -e "$dir/calls.log" ] && grep -q 'list is a read' <<< "$out"
check "list refuses --dry-run instead of silently sending" $?

setup
run delete
[ $code -ne 0 ] && grep -q 'delete: give one or more ids' <<< "$out"
check "delete with no ids refuses" $?

if [ $failures -gt 0 ]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all recon CLI tests passed"
