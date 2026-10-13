#!/usr/bin/env bash
# Tests for plugin/hooks/guard.sh, the PreToolUse hook that keeps the
# live-verifier subagent's Bash read-only and keeps every Harness browser page
# in the background. Each case feeds the hook a PreToolUse input and asserts it
# allows (no output) or denies (a deny decision).
# Needs node, like the hook itself.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GUARD="$HERE/../plugin/hooks/guard.sh"
failures=0

# A repo whose Project config names a fixture reset command and a read-only CLI.
REPO="$(mktemp -d)"
trap 'rm -rf "$REPO"' EXIT
mkdir -p "$REPO/docs/agents"
cat > "$REPO/docs/agents/harness.md" <<'MD'
# Harness: Project config

## Fixtures

- **Convention**: seed data in `fixtures/`, loaded into the dev database
- **Reset**: `npm run fixtures:reset`

## Data connectors

- **Analytics warehouse**: CLI `warehouse query`; read-only
- **Orders DB**: CLI `orders-admin`; read-write
MD
BARE="$(mktemp -d)"
trap 'rm -rf "$REPO" "$BARE"' EXIT

# hook_input <agent_type> <command> [cwd]
hook_input() {
  node -e '
    const [agent, command, cwd] = process.argv.slice(1);
    const input = { hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: { command }, cwd };
    if (agent) input.agent_type = agent;
    process.stdout.write(JSON.stringify(input));
  ' "$1" "$2" "${3:-$REPO}"
}

# expect <allow|deny> <command> [agent_type] [cwd]
expect() {
  local want="$1" cmd="$2" agent="${3-harness:live-verifier}" cwd="${4:-$REPO}"
  local out code got
  out="$(hook_input "$agent" "$cmd" "$cwd" | "$GUARD" 2>&1)"
  code=$?
  if [[ $code -eq 0 && -z "$out" ]]; then
    got=allow
  elif [[ $code -eq 0 && "$out" == *'"permissionDecision":"deny"'* ]]; then
    got=deny
  else
    got="error (exit $code)"
  fi
  if [[ "$got" == "$want" ]]; then
    echo "ok   - $want: ${cmd//$'\n'/\\n}${agent:+ [$agent]}"
  else
    echo "FAIL - want $want, got $got: $cmd${agent:+ [$agent]}"
    [[ -n "$out" ]] && echo "$out" | sed 's/^/       /'
    failures=$((failures + 1))
  fi
}

echo "# other agents and the main session are untouched"
expect allow 'rm -rf build' ''
expect allow 'git push origin main' 'Explore'
expect allow 'curl -X POST https://api.example.com/items' 'other-plugin:verifier'

echo "# read-only inspection"
expect allow 'ls -la'
expect allow 'cat docs/agents/harness.md'
expect allow 'grep -rn "tag" src | head -20'
expect allow 'git -C . log --oneline -5'
expect allow 'git status --short && git diff origin/main --stat'
expect allow 'git branch --show-current'
expect allow 'find . -name "*.md" -type f'
expect allow 'cd src && ls'
expect allow 'jq ".items | length" response.json'
expect deny 'base64 -o out.txt in.txt'
expect allow "jq '.[] | select(.n > 1)' data.json"
expect allow 'sort names.txt | uniq -c'
expect allow 'grep -c tag notes.json 2>/dev/null'
expect allow 'git log -1 2>&1 | head -5'
expect allow 'wc -l < notes.json'
expect allow 'ls' 'live-verifier'

echo "# GitHub reads"
expect allow 'gh issue view 42 --json title,body'
expect allow 'gh pr view 12 --json body,url'
expect allow 'gh pr checks 12'
expect allow 'gh run list --branch main --limit 5'
expect allow 'gh api repos/{owner}/{repo}/deployments --jq ".[0].sha"'
expect allow 'gh api -X GET search/issues -f q=repo:octo/notes'
expect allow 'gh api graphql -f query="query { viewer { login } }"'

echo "# HTTP reads"
expect allow 'curl -s https://dev.example.com/api/notes?tag=work'
expect allow 'curl -sS -o /dev/null -w "%{http_code}" https://example.com/health'
expect allow 'curl -sSL -H "Accept: application/json" https://example.com/api/items'
expect allow 'curl -I https://example.com'
expect allow 'curl -G --data-urlencode "q=tag:work" https://example.com/search'
expect allow 'curl -s -H "Authorization: Bearer $DEV_TOKEN" https://dev.example.com/api/me'

echo "# Project config: fixture reset and read-only connectors"
expect allow 'npm run fixtures:reset'
expect allow 'warehouse query "select count(*) from notes"'
expect deny 'orders-admin list'
expect deny 'npm run fixtures:reset' 'harness:live-verifier' "$BARE"
expect deny 'npm run fixtures:reset && npm run deploy'

echo "# writes to the repo or disk"
expect deny 'rm -rf build'
expect deny 'echo hi > notes.txt'
expect deny 'echo hi >> notes.txt'
expect deny 'cat a | tee b'
expect deny 'touch x'
expect deny 'mv a b'
expect deny 'sed -i "" s/a/b/ file'
expect deny 'find . -name "*.log" -delete'
expect deny 'find . -exec rm {} ;'
expect deny 'sort -o out.txt in.txt'
expect deny 'uniq in.txt out.txt'
expect deny 'git commit -m wip'
expect deny 'git checkout main'
expect deny 'git branch new-branch'
expect deny 'git diff --output=patch.diff'
expect deny 'git -c core.pager=sh log'
expect deny 'git branch -D old'
expect deny 'git config user.name x'
expect deny 'git stash drop'
expect deny 'rm -rf build' 'live-verifier'

echo "# writes to remote systems"
expect deny 'git push origin main'
expect deny 'gh pr merge 12 --squash'
expect deny 'gh issue comment 42 --body done'
expect deny 'gh issue close 42'
expect deny 'gh api -X POST repos/{owner}/{repo}/issues -f title=x'
expect deny 'gh api --method=PATCH repos/{owner}/{repo}/issues/4'
expect deny 'gh api repos/{owner}/{repo}/issues -f title=x'
expect deny 'gh api repos/{owner}/{repo}/issues --input body.json'
expect deny 'gh api graphql -f query="mutation { closeIssue(input: {}) { clientMutationId } }"'
expect deny 'gh run rerun 99'
expect deny 'curl -X POST https://api.example.com/items'
expect deny 'curl -XDELETE https://api.example.com/items/1'
expect deny 'curl -sXPUT https://api.example.com/items/1'
expect deny 'curl --request PATCH https://api.example.com/items/1'
expect deny 'curl -d "a=1" https://api.example.com/items'
expect deny 'curl -sd "a=1" https://api.example.com/items'
expect deny 'curl --json "{}" https://api.example.com/items'
expect deny 'curl -F file=@a.png https://api.example.com/upload'
expect deny 'curl -T a.txt https://api.example.com/upload'
expect deny 'curl -o page.html https://example.com'
expect deny 'curl -O https://example.com/file.zip'
expect deny 'curl -K cfg https://example.com'

echo "# ways around the checks"
expect deny 'ls $(rm -rf build)'
expect deny 'ls `rm -rf build`'
expect deny 'ls; rm -rf build'
expect deny 'ls & rm -rf build'
expect deny 'ls || rm -rf build'
expect deny "ls
rm -rf build"
expect deny 'cat <(curl -X POST https://x.example.com)'
expect deny 'cat <<EOF'
expect deny 'FOO=1 rm x'
expect deny 'curl $FLAGS https://example.com'
expect deny '/bin/rm -rf build'
expect deny 'bash -c "rm -rf build"'
expect deny 'sh scripts/deploy.sh'
expect deny 'node -e "1"'
expect deny 'python3 -c "1"'
expect deny 'xargs rm < list.txt'
expect deny 'env rm x'
expect deny '(rm x)'
expect deny 'eval ls'
expect deny 'gh pr view 12 --web'
expect deny 'curl "$FLAGS" https://example.com'

out="$(printf '{"agent_type":"harness:live-verifier", broken' | "$GUARD")"
if [[ "$out" == *'"permissionDecision":"deny"'* ]]; then
  echo "ok   - deny: unreadable input that names live-verifier"
else
  echo "FAIL - want deny for unreadable input, got: $out"
  failures=$((failures + 1))
fi

echo "# Harness browser pages stay in the background, for every agent"
# expect_browser <allow|deny> <tool> <tool_input json> [agent_type]
expect_browser() {
  local want="$1" tool="$2" json="$3" agent="${4-}"
  local input out got
  input="{\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"mcp__plugin_harness_browser__$tool\",\"tool_input\":$json${agent:+,\"agent_type\":\"$agent\"}}"
  out="$(printf '%s' "$input" | "$GUARD" 2>&1)"
  if [[ -z "$out" ]]; then
    got=allow
  elif [[ "$out" == *'"permissionDecision":"deny"'* ]]; then
    got=deny
  else
    got=error
  fi
  if [[ "$got" == "$want" ]]; then
    echo "ok   - $want: $tool $json${agent:+ [$agent]}"
  else
    echo "FAIL - want $want, got $got: $tool $json${agent:+ [$agent]}"
    [[ -n "$out" ]] && echo "$out" | sed 's/^/       /'
    failures=$((failures + 1))
  fi
}
expect_browser allow new_page '{"url":"https://dev.example.com","background":true}' 'harness:live-verifier'
expect_browser allow new_page '{"url":"https://dev.example.com","background":true}'
expect_browser deny new_page '{"url":"https://dev.example.com"}' 'harness:live-verifier'
expect_browser deny new_page '{"url":"https://dev.example.com","background":false}'
expect_browser allow select_page '{"pageId":2}' 'harness:live-verifier'
expect_browser allow select_page '{"pageId":2,"bringToFront":false}'
expect_browser deny select_page '{"pageId":2,"bringToFront":true}'
expect_browser allow navigate_page '{"url":"https://dev.example.com"}'

if [[ $failures -gt 0 ]]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
