#!/usr/bin/env bash
# Post-format — runs auto-formatters after Write/Edit operations
set -euo pipefail

file_path=$(jq -r '.tool_input.file_path // ""' 2>/dev/null || true)

if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
  exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$project_dir"

# Detect and run available formatter — skip if none found
case "$file_path" in
  *.js|*.jsx|*.ts|*.tsx|*.css|*.json|*.md|*.yaml|*.yml|*.html)
    if command -v npx >/dev/null 2>&1 && [ -f "$project_dir/.prettierrc" -o -f "$project_dir/.prettierrc.js" -o -f "$project_dir/.prettierrc.json" -o -f "$project_dir/prettier.config.js" ]; then
      npx prettier --write "$file_path" 2>/dev/null || true
    fi
    ;;
  *.py)
    if command -v black >/dev/null 2>&1; then
      black --quiet "$file_path" 2>/dev/null || true
    fi
    ;;
  *.go)
    if command -v gofmt >/dev/null 2>&1; then
      gofmt -w "$file_path" 2>/dev/null || true
    fi
    ;;
  *.tf|*.tfvars)
    if command -v terraform >/dev/null 2>&1; then
      terraform fmt "$file_path" 2>/dev/null || true
    fi
    ;;
esac

exit 0
