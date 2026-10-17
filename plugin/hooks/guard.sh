#!/usr/bin/env bash
# PreToolUse hook for every tool call. Keeps the read-only subagents
# (live-verifier, data-digest) read-only, and keeps every Harness browser page
# in the background (S10); anything else passes straight through.
# The checks live in guard.mjs. Without node, the read-only subagents' guarded
# calls are denied rather than let through unchecked.
input="$(cat)"
case "$input" in
  *live-verifier* | *data-digest* | *mcp__plugin_harness_browser__*) ;;
  *) exit 0 ;;
esac

if command -v node >/dev/null 2>&1; then
  printf '%s' "$input" | node "$(dirname "$0")/guard.mjs"
  exit $?
fi

# No node: deny only if this really is a read-only subagent (agent_type ends in
# its name) making a call the guard would check. The browser itself runs on
# node, so its page tools need no fallback.
deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
}
tool_is() { printf '%s' "$input" | grep -Eq "\"tool_name\"[[:space:]]*:[[:space:]]*\"$1"; }
agent_is() { printf '%s' "$input" | grep -Eq "\"agent_type\"[[:space:]]*:[[:space:]]*\"([^\"]*:)?$1\""; }
if agent_is live-verifier && tool_is 'Bash"'; then
  deny "live-verifier Bash guard needs node, which is not on PATH, so Bash is unavailable to live-verifier. Use the browser tools or WebFetch for reads."
elif agent_is data-digest && ! tool_is '(Read|Grep|Glob)"'; then
  deny "data-digest guard needs node, which is not on PATH, so data-digest has only Read, Grep and Glob. Report BLOCKED."
fi
exit 0
