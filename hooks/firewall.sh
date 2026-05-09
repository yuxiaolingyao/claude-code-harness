#!/usr/bin/env bash
# Command firewall — PreToolUse:Bash
# Reads rules/dangerous-commands.json, blocks dangerous shell commands.
# Mode: reads ~/.claude/harness-mode.json (enforce|ask|audit, default: enforce)
# Fail-closed: blocks if rules cannot be read or parsed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_FILE="$SCRIPT_DIR/../rules/dangerous-commands.json"
MODE_FILE="$HOME/.claude/harness-mode.json"
AUDIT_LOG="$HOME/.claude/logs/audit.jsonl"

# ── Read mode ──
MODE="enforce"
if [ -f "$MODE_FILE" ]; then
  MODE=$(jq -r '.mode // "enforce"' "$MODE_FILE" 2>/dev/null | tr -d '\r' || echo "enforce")
fi
case "$MODE" in enforce|ask|audit) ;; *) MODE="enforce" ;; esac

cmd=$(jq -r '.tool_input.command // ""' 2>/dev/null | tr -d '\r' || true)

if [ -z "$cmd" ]; then
  echo "SECURITY BLOCK: unable to parse tool input (jq error or empty command)" >&2
  exit 2
fi

if [ ! -f "$RULES_FILE" ]; then
  echo "SECURITY BLOCK: rules file not found at $RULES_FILE" >&2
  exit 2
fi

categories=$(jq -r '.categories | keys[]' "$RULES_FILE" 2>/dev/null | tr -d '\r' || true)
if [ -z "$categories" ]; then
  echo "SECURITY BLOCK: unable to parse rules file $RULES_FILE" >&2
  exit 2
fi

blocked_category=""
blocked_pattern=""

while IFS= read -r category; do
  patterns=$(jq -r ".categories[\"$category\"].patterns[]?" "$RULES_FILE" 2>/dev/null | tr -d '\r' || true)
  if [ -z "$patterns" ]; then
    continue
  fi
  while IFS= read -r pattern; do
    if echo "$cmd" | grep -Eiq -- "$pattern"; then
      blocked_category="$category"
      blocked_pattern="$pattern"
      break 2
    fi
  done <<< "$patterns"
done <<< "$categories"

if [ -n "$blocked_category" ]; then
  mkdir -p "$(dirname "$AUDIT_LOG")"
  jq -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg hook "firewall" \
    --arg mode "$MODE" \
    --arg category "$blocked_category" \
    --arg cmd "$cmd" \
    '{ts:$ts, hook:$hook, mode:$mode, decision:$mode, category:$category, cmd:$cmd}' \
    >> "$AUDIT_LOG" 2>/dev/null || true

  case "$MODE" in
    enforce)
      echo "SECURITY BLOCK: $blocked_category — $cmd" >&2
      exit 2
      ;;
    ask)
      jq -n --arg reason "[$blocked_category] $cmd" '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "ask",
          permissionDecisionReason: $reason
        }
      }'
      exit 0
      ;;
    audit)
      exit 0
      ;;
  esac
fi

exit 0
