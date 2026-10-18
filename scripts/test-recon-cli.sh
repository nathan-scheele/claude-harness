#!/usr/bin/env bash
# Tests for the CLI template private-api-recon copies into a target repo
# (plugin/skills/private-api-recon/cli.sh). Each case copies it into a
# throwaway directory and runs it with a fake curl first on PATH that logs its
# arguments and stdin to calls.log, so nothing leaves the machine.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CLI="$HERE/../plugin/skills/private-api-recon/cli.sh"
TOKEN=tok-test-5e1d9a
failures=0

# A fresh copy of the CLI in $dir/cli/items, the fake curl in $dir/bin.
setup() {
  dir="$(mktemp -d)"
  mkdir -p "$dir/cli" "$dir/bin"
  cp "$CLI" "$dir/cli/items"
  chmod +x "$dir/cli/items"
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
  printf '{"name":"one"}\n{"name":"two"}\n{"name":"three"}\n' > "$dir/items.jsonl"
}

run() { # run <args>...: runs the CLI with the fake curl; sets out, code
  out="$(cd "$dir" && PATH="$dir/bin:$PATH" cli/items "$@" 2>&1)"
  code=$?
}

calls() { cat "$dir/calls.log" 2>/dev/null; }

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
[ $code -eq 0 ] && [ ! -e "$dir/calls.log" ] && grep -q 'DRY RUN POST https://api.example.com/v1/items {"name":"two"}' <<< "$out" &&
  grep -q '3 item(s) would be created' <<< "$out"
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
run create items.jsonl
[ $code -ne 0 ] && [ ! -e "$dir/calls.log" ] && grep -q 'no token: set EXAMPLE_TOKEN' <<< "$out"
check "no token: a real run stops before any request" $?

setup
export EXAMPLE_TOKEN="$TOKEN"
run create items.jsonl --limit 1
unset EXAMPLE_TOKEN
[ $code -eq 0 ] && [ "$(calls | grep -c '^ARGS')" -eq 1 ] && calls | grep -q '^ARGS .*-X POST https://api.example.com/v1/items .*--data-binary {"name":"one"}' &&
  calls | grep -q "^STDIN authorization: Bearer $TOKEN\$" && grep -q '1 item(s) created' <<< "$out"
check "--limit 1 sends only the first item, token from the environment on stdin" $?

setup
printf 'EXAMPLE_TOKEN=%s\n' "$TOKEN" > "$dir/cli/.env"
run create items.jsonl --offset 1
[ $code -eq 0 ] && [ "$(calls | grep -c '^ARGS')" -eq 2 ] && ! calls | grep -q '"one"' && calls | grep -q '"three"' &&
  calls | grep -q "^STDIN authorization: Bearer $TOKEN\$"
check "--offset 1 sends the rest, token from .env beside the CLI" $?

setup
export EXAMPLE_TOKEN="$TOKEN"
run list
unset EXAMPLE_TOKEN
! calls | grep '^ARGS' | grep -q "$TOKEN" && ! grep -q "$TOKEN" <<< "$out" &&
  calls | grep -q '^ARGS .*-H origin: https://app.example.com -H referer: https://app.example.com/'
check "the token never reaches curl's arguments or the output; Origin and Referer are sent" $?

setup
export EXAMPLE_TOKEN="$TOKEN" FAKE_CURL_FAIL='"two"'
run create items.jsonl
unset EXAMPLE_TOKEN FAKE_CURL_FAIL
[ $code -ne 0 ] && [ "$(calls | grep -c '^ARGS')" -eq 2 ] && ! calls | grep -q '"three"' && grep -q 'failed; stopped' <<< "$out"
check "a failed request stops the run" $?

setup
export EXAMPLE_TOKEN="$TOKEN"
run list --dry-run
unset EXAMPLE_TOKEN
[ $code -eq 0 ] && calls | grep -q '^ARGS .*-X GET https://api.example.com/v1/items'
check "list is a read and always runs" $?

setup
run delete
[ $code -ne 0 ] && grep -q 'delete: give one or more ids' <<< "$out"
check "delete with no ids refuses" $?

if [ $failures -gt 0 ]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all recon CLI tests passed"
