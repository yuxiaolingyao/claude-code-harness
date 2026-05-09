#!/usr/bin/env bash
# PreCompact — saves critical context before Claude compacts conversation
set -euo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
backup_dir="$HOME/.claude/compact-backups"
mkdir -p "$backup_dir"

ts=$(date -u +%Y%m%d_%H%M%SZ)
out="$backup_dir/${ts}.json"

# Collect git diff summary
git_diff=$(cd "$project_dir" && git diff --stat 2>/dev/null || echo "N/A")

# Build snapshot
jq -n \
  --arg ts "$ts" \
  --arg project "$project_dir" \
  --arg git_diff "$git_diff" \
  '{ts:$ts, project:$project, git_diff:$git_diff}' \
  > "$out" 2>/dev/null || true

# Rotate: keep last 20
ls -1t "$backup_dir"/*.json 2>/dev/null | tail -n +21 | xargs rm -f 2>/dev/null || true

exit 0
