#!/usr/bin/env bash
# Sentinel — PostToolUse:* (runs after any tool)
# Detects brute-force loops, edit cycling, and analysis paralysis.
# When triggered, injects a warning into stderr for Claude to see.
# Never blocks (exit 0) — this is advisory, not enforcement.
set -euo pipefail

SENTINEL_LOG="$HOME/.claude/logs/sentinel.jsonl"
SENTINEL_DIR="$(dirname "$SENTINEL_LOG")"
mkdir -p "$SENTINEL_DIR"

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null | tr -d '\r' || true)

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ── Log the tool call ──
case "$tool_name" in
  Bash)
    cmd=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null | tr -d '\r' || true)
    # Normalize: strip variable values and paths for pattern matching
    normalized=$(echo "$cmd" | sed 's/"[^"]*"/"..."/g; s/\x27[^\x27]*\x27/.../g; s/\/[a-zA-Z0-9._-]\+/[path]/g')
    jq -n --arg ts "$ts" --arg tool "Bash" --arg cmd "$normalized" '{ts:$ts, tool:$tool, cmd:$cmd}' >> "$SENTINEL_LOG" 2>/dev/null || true
    ;;
  Write|Edit)
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null | tr -d '\r' || true)
    jq -n --arg ts "$ts" --arg tool "$tool_name" --arg file "$file_path" '{ts:$ts, tool:$tool, file:$file}' >> "$SENTINEL_LOG" 2>/dev/null || true
    ;;
  *)
    exit 0
    ;;
esac

# ── Rotate: keep last 200 entries ──
entries=$(wc -l < "$SENTINEL_LOG" 2>/dev/null || echo 0)
if [ "$entries" -gt 200 ]; then
  tail -200 "$SENTINEL_LOG" > "$SENTINEL_LOG.tmp" 2>/dev/null && mv "$SENTINEL_LOG.tmp" "$SENTINEL_LOG" 2>/dev/null || true
fi

# ── Detection ──
warnings=""

# 1. Brute-force: same Bash command ≥3 times in last 20 entries
if [ "$tool_name" = "Bash" ]; then
  repeat_count=$(tail -20 "$SENTINEL_LOG" 2>/dev/null | jq -r 'select(.tool=="Bash") | .cmd' | sort | uniq -c | sort -rn | head -1 | awk '{print $1}' || echo 0)
  if [ "${repeat_count:-0}" -ge 3 ]; then
    warnings="${warnings}BRUTE-FORCE: same command repeated $repeat_count times. Stop and reconsider your approach. Ask the user for guidance instead of retrying.\n"
  fi
fi

# 2. Edit loop: same file edited ≥5 times in last 30 entries
if [ "$tool_name" = "Write" ] || [ "$tool_name" = "Edit" ]; then
  edit_count=$(tail -30 "$SENTINEL_LOG" 2>/dev/null | jq -r "select(.file==\"$file_path\") | .file" | wc -l || echo 0)
  if [ "${edit_count:-0}" -ge 5 ]; then
    warnings="${warnings}EDIT-LOOP: file '$file_path' edited $edit_count times in recent history. The current approach may be wrong — stop and reconsider.\n"
  fi
fi

# 3. Analysis paralysis: 10+ Bash calls without any Write/Edit
bash_count=$(tail -15 "$SENTINEL_LOG" 2>/dev/null | jq -r 'select(.tool=="Bash") | .tool' | wc -l || echo 0)
write_count=$(tail -15 "$SENTINEL_LOG" 2>/dev/null | jq -r 'select(.tool=="Write" or .tool=="Edit") | .tool' | wc -l || echo 0)
if [ "${bash_count:-0}" -ge 10 ] && [ "${write_count:-0}" -eq 0 ]; then
  warnings="${warnings}ANALYSIS-PARALYSIS: $bash_count reads/commands without any edits. You have enough information — start making changes.\n"
fi

# ── Output ──
if [ -n "$warnings" ]; then
  echo "" >&2
  echo "╔══════════════════════════════════╗" >&2
  echo "║  SENTINEL: LOOP DETECTED         ║" >&2
  echo "╚══════════════════════════════════╝" >&2
  echo -e "$warnings" >&2
fi

exit 0
