#!/usr/bin/env bash
# Sensitive content guard — PreToolUse:Write|Edit
# Scans NEW content being written for secrets, API keys, tokens, private keys.
# Mode: reads ~/.claude/harness-mode.json (enforce|ask|audit, default: enforce)
# Fail-closed: blocks if rules cannot be read or parsed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_FILE="$SCRIPT_DIR/../rules/sensitive-content.json"
MODE_FILE="$HOME/.claude/harness-mode.json"
AUDIT_LOG="$HOME/.claude/logs/audit.jsonl"

# ── Read mode ──
MODE="enforce"
if [ -f "$MODE_FILE" ]; then
  MODE=$(jq -r '.mode // "enforce"' "$MODE_FILE" 2>/dev/null | tr -d '\r' || echo "enforce")
fi
case "$MODE" in enforce|ask|audit) ;; *) MODE="enforce" ;; esac

# Read stdin once into variable (multiple jq calls would each consume stdin)
input=$(cat)

file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null | tr -d '\r' || true)
content=$(echo "$input" | jq -r '.tool_input.content // ""' 2>/dev/null | tr -d '\r' || true)

if [ -z "$file_path" ]; then
  echo "SECURITY BLOCK: unable to parse file_path from tool input" >&2
  exit 2
fi

if [ -z "$content" ]; then
  exit 0
fi

case "$file_path" in
  *.png|*.jpg|*.jpeg|*.gif|*.ico|*.svg|*.pdf|*.zip|*.tar|*.gz|*.bz2|*.bin|*.exe|*.dll|*.so|*.class|*.jar|*.war|*.lock|*.min.js|*.min.css|*.map)
    exit 0
    ;;
esac

if [ ! -f "$RULES_FILE" ]; then
  echo "SECURITY BLOCK: rules file not found at $RULES_FILE" >&2
  exit 2
fi

blocked_type=""
blocked_pattern=""
found_match=""

categories=$(jq -r '.patterns | keys[]' "$RULES_FILE" 2>/dev/null | tr -d '\r' || true)
if [ -z "$categories" ]; then
  echo "SECURITY BLOCK: unable to parse rules file $RULES_FILE" >&2
  exit 2
fi

while IFS= read -r category; do
  patterns=$(jq -r ".patterns[\"$category\"].patterns[]?" "$RULES_FILE" 2>/dev/null | tr -d '\r' || true)
  if [ -z "$patterns" ]; then
    continue
  fi
  while IFS= read -r pattern; do
    matched=$(echo "$content" | grep -Eo -- "$pattern" | head -1 || true)
    if [ -n "$matched" ]; then
      blocked_type="$category"
      blocked_pattern="$pattern"
      found_match="$matched"
      break 2
    fi
  done <<< "$patterns"
done <<< "$categories"

if [ -n "$blocked_type" ]; then
  masked="${found_match:0:4}...${found_match: -4}"

  mkdir -p "$(dirname "$AUDIT_LOG")"
  jq -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg hook "content-guard" \
    --arg mode "$MODE" \
    --arg type "$blocked_type" \
    --arg file "$file_path" \
    --arg masked "$masked" \
    '{ts:$ts, hook:$hook, mode:$mode, decision:$mode, type:$type, file:$file, masked:$masked}' \
    >> "$AUDIT_LOG" 2>/dev/null || true

  case "$MODE" in
    enforce)
      jq -n --arg reason "$blocked_type found in $file_path ($masked)" '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: $reason
        }
      }'
      exit 0
      ;;
    ask)
      jq -n --arg reason "$blocked_type found in $file_path ($masked)" '{
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
