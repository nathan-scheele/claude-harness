#!/usr/bin/env bash
# PreToolUse hook for Bash. Keeps the live-verifier subagent's shell read-only;
# every other agent and the main session pass straight through.
# The checks live in live-verifier-guard.mjs. Without node, live-verifier's
# Bash calls are denied rather than let through unchecked.
input="$(cat)"
case "$input" in
  *live-verifier*) ;;
  *) exit 0 ;;
esac

if command -v node >/dev/null 2>&1; then
  printf '%s' "$input" | node "$(dirname "$0")/live-verifier-guard.mjs"
  exit $?
fi

# No node: deny only if this really is live-verifier (agent_type ends in live-verifier).
if printf '%s' "$input" | grep -Eq '"agent_type"[[:space:]]*:[[:space:]]*"([^"]*:)?live-verifier"'; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"live-verifier Bash guard needs node, which is not on PATH, so Bash is unavailable to live-verifier. Use the browser tools or WebFetch for reads."}}'
fi
exit 0
