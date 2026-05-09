#!/usr/bin/env bash
# Auto-verify — PostToolUse:Write|Edit
# Detects project build system and runs compile after file changes.
# Reports errors to stderr so Claude sees them. Never blocks (exit 0).
# This is the first pass of the self-verification loop.
set -euo pipefail

file_path=$(jq -r '.tool_input.file_path // ""' 2>/dev/null | tr -d '\r' || true)

if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
  exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$project_dir"

# Only run verification for code files (skip docs, config, assets)
case "$file_path" in
  *.md|*.txt|*.json|*.yaml|*.yml|*.css|*.html|*.svg|*.png|*.jpg|*.gif)
    exit 0
    ;;
esac

# ── Detect build system and run compile ──

run_verify() {
  local cmd="$1"
  local label="$2"
  # Timeout after 30s — compile verification shouldn't block the agent
  if command -v timeout >/dev/null 2>&1; then
    timeout 30 $cmd 2>&1 || true
  else
    # macOS / Git Bash without timeout
    $cmd 2>&1 || true
  fi
}

result=""

# Maven
if [ -f "pom.xml" ]; then
  result=$(run_verify "mvn compile -q" "maven" 2>&1) || true

# Gradle
elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
  result=$(run_verify "gradle compileJava -q" "gradle" 2>&1) || true

# Cargo
elif [ -f "Cargo.toml" ]; then
  result=$(run_verify "cargo check 2>&1" "cargo" 2>&1) || true

# Go
elif [ -f "go.mod" ]; then
  result=$(run_verify "go build ./... 2>&1" "go" 2>&1) || true

# TypeScript
elif [ -f "tsconfig.json" ]; then
  result=$(run_verify "npx tsc --noEmit 2>&1" "tsc" 2>&1) || true

# JavaScript/Node
elif [ -f "package.json" ]; then
  # Only if build script exists
  if grep -q '"build"' package.json 2>/dev/null; then
    result=$(run_verify "npm run build 2>&1" "npm" 2>&1) || true
  fi

# Make
elif [ -f "Makefile" ]; then
  result=$(run_verify "make -q 2>&1" "make" 2>&1) || true

# Python (syntax check only — fast)
elif [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
  if echo "$file_path" | grep -q '\.py$'; then
    result=$(python3 -m py_compile "$file_path" 2>&1 || python -m py_compile "$file_path" 2>&1) || true
  fi
fi

# ── Output ──
if [ -n "$result" ]; then
  # Filter: only show actual errors (skip warnings and "BUILD SUCCESS")
  errors=$(echo "$result" | grep -iE 'error|FAIL|failed|cannot|not found|undeclared|undefined' | head -20 || true)
  if [ -n "$errors" ]; then
    echo "--- VERIFICATION FAILED ---" >&2
    echo "$errors" >&2
    echo "---------------------------" >&2
    echo "" >&2
    echo "Fix the errors above before proceeding." >&2
  fi
fi

exit 0
