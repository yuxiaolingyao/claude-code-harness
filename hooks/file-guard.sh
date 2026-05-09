#!/usr/bin/env bash
# Sensitive file path guard — PreToolUse:Write|Edit
# Reads rules/sensitive-files.json, blocks writes to sensitive paths.
# Mode: reads ~/.claude/harness-mode.json (enforce|ask|audit, default: enforce)
# Fail-closed: blocks if rules cannot be read or parsed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_FILE="$SCRIPT_DIR/../rules/sensitive-files.json"
MODE_FILE="$HOME/.claude/harness-mode.json"
AUDIT_LOG="$HOME/.claude/logs/audit.jsonl"

# ── Read mode ──
MODE="enforce"
if [ -f "$MODE_FILE" ]; then
  MODE=$(jq -r '.mode // "enforce"' "$MODE_FILE" 2>/dev/null | tr -d '\r' || echo "enforce")
fi
case "$MODE" in enforce|ask|audit) ;; *) MODE="enforce" ;; esac

file_path=$(jq -r '.tool_input.file_path // ""' 2>/dev/null | tr -d '\r' || true)

if [ -z "$file_path" ]; then
  echo "SECURITY BLOCK: unable to parse file_path from tool input" >&2
  exit 2
fi

if [ ! -f "$RULES_FILE" ]; then
  echo "SECURITY BLOCK: rules file not found at $RULES_FILE" >&2
  exit 2
fi

patterns=$(jq -r '.patterns[]?' "$RULES_FILE" 2>/dev/null | tr -d '\r' || true)
if [ -z "$patterns" ]; then
  echo "SECURITY BLOCK: unable to parse rules file $RULES_FILE" >&2
  exit 2
fi

blocked_pattern=""

while IFS= read -r pattern; do
  if echo "$file_path" | grep -Eiq "$pattern"; then
    blocked_pattern="$pattern"
    break
  fi
done <<< "$patterns"

if [ -n "$blocked_pattern" ]; then
  mkdir -p "$(dirname "$AUDIT_LOG")"
  jq -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg hook "file-guard" \
    --arg mode "$MODE" \
    --arg pattern "$blocked_pattern" \
    --arg file "$file_path" \
    '{ts:$ts, hook:$hook, mode:$mode, decision:$mode, pattern:$pattern, file:$file}' \
    >> "$AUDIT_LOG" 2>/dev/null || true

  case "$MODE" in
    enforce)
      echo "SECURITY BLOCK: sensitive file — $file_path" >&2
      exit 2
      ;;
    ask)
      jq -n --arg reason "Sensitive file: $file_path" '{
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
