#!/usr/bin/env bash
# Session start — injects project state at session startup
set -euo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

echo "--- Project State ---"
cd "$project_dir" && git status --short 2>/dev/null || true
echo ""
cd "$project_dir" && git log --oneline -3 2>/dev/null || true
echo ""

# Print TODO if exists
for f in TODO.md TODO.txt plan.md PLAN.md; do
  if [ -f "$project_dir/$f" ]; then
    echo "--- $f ---"
    cat "$project_dir/$f"
    echo ""
    break
  fi
done

exit 0
