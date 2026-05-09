#!/usr/bin/env bash
# Conformance test suite for Claude Code Harness hooks
# Usage: bash tests/conformance.sh [--strict] [--smoke]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../hooks"
RULES_DIR="$SCRIPT_DIR/../rules"

PASS=0
FAIL=0
ERRORS=""

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Preflight
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required for conformance tests"
  exit 1
fi

if [ ! -d "$HOOKS_DIR" ]; then
  echo "ERROR: hooks directory not found: $HOOKS_DIR"
  exit 1
fi

if [ ! -d "$RULES_DIR" ]; then
  echo "ERROR: rules directory not found: $RULES_DIR"
  exit 1
fi

# ── Helpers ──

run_hook() {
  local hook="$1" stdin="$2"
  echo "$stdin" | bash "$hook" 2>/dev/null
  echo $?
}

test_hook() {
  local hook="$1" stdin="$2" expected="$3" label="$4"
  local actual
  actual=$(echo "$stdin" | bash "$hook" 2>/dev/null; echo $?)
  actual="${actual##*$'\n'}"
  if [ "$actual" -eq "$expected" ]; then
    echo -e "  ${GREEN}PASS${NC} $label"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} $label (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: $label"
  fi
}

run_corpus_commands() {
  local hook="$1" corpus="$2" expected="$3" prefix="$4"
  [ ! -f "$corpus" ] && echo "  SKIP: $corpus not found" && return
  local count=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      \#*) continue ;;
      '')   continue ;;
    esac
    count=$((count + 1))
    local stdin
    stdin=$(jq -n --arg cmd "$line" '{tool_input:{command:$cmd}}')
    test_hook "$hook" "$stdin" "$expected" "${prefix}#${count}: ${line:0:70}"
  done < "$corpus"
}

run_corpus_paths() {
  local hook="$1" corpus="$2" expected="$3" prefix="$4"
  [ ! -f "$corpus" ] && echo "  SKIP: $corpus not found" && return
  local count=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      \#*) continue ;;
      '')   continue ;;
    esac
    count=$((count + 1))
    local stdin
    stdin=$(jq -n --arg fp "$line" '{tool_input:{file_path:$fp}}')
    test_hook "$hook" "$stdin" "$expected" "${prefix}#${count}: ${line:0:70}"
  done < "$corpus"
}

run_corpus_content() {
  local hook="$1" corpus="$2" expected="$3" prefix="$4"
  [ ! -f "$corpus" ] && echo "  SKIP: $corpus not found" && return
  local count=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      \#*) continue ;;
      '')   continue ;;
    esac
    count=$((count + 1))
    local stdin
    stdin=$(jq -n --arg fp "test.txt" --arg content "$line" '{tool_input:{file_path:$fp, content:$content}}')
    test_hook "$hook" "$stdin" "$expected" "${prefix}#${count}: ${line:0:70}"
  done < "$corpus"
}

echo "=== Claude Code Harness Conformance Tests ==="
echo ""

# ── 1. Firewall adversarial (must BLOCK = exit 2) ──
echo "[1/6] Firewall — adversarial (must BLOCK)"
for corpus in "$SCRIPT_DIR/adversarial-corpus/bash-bypass.txt" \
              "$SCRIPT_DIR/adversarial-corpus/credential-exfil.txt" \
              "$SCRIPT_DIR/adversarial-corpus/reverse-shell.txt" \
              "$SCRIPT_DIR/adversarial-corpus/command-injection.txt" \
              "$SCRIPT_DIR/adversarial-corpus/encoding-bypass.txt"; do
  [ -f "$corpus" ] || { echo "  SKIP: $(basename "$corpus") not found"; continue; }
  name=$(basename "$corpus" .txt)
  run_corpus_commands "$HOOKS_DIR/firewall.sh" "$corpus" 2 "adversary/$name"
done

# ── 2. Firewall false-positive (must ALLOW = exit 0) ──
echo "[2/6] Firewall — false-positive (must ALLOW)"
run_corpus_commands "$HOOKS_DIR/firewall.sh" "$SCRIPT_DIR/false-positive-corpus/legitimate-commands.txt" 0 "legit/commands"

# ── 3. File-guard adversarial (must BLOCK) ──
echo "[3/6] File-guard — adversarial (must BLOCK)"
run_corpus_paths "$HOOKS_DIR/file-guard.sh" "$SCRIPT_DIR/adversarial-corpus/sensitive-files.txt" 2 "adversary/files"

# ── 4. File-guard false-positive (must ALLOW) ──
echo "[4/6] File-guard — false-positive (must ALLOW)"
run_corpus_paths "$HOOKS_DIR/file-guard.sh" "$SCRIPT_DIR/false-positive-corpus/safe-file-paths.txt" 0 "legit/files"

# ── 5. Content-guard adversarial (must BLOCK) ──
echo "[5/6] Content-guard — adversarial (must BLOCK)"
run_corpus_content "$HOOKS_DIR/content-guard.sh" "$SCRIPT_DIR/adversarial-corpus/secret-content.txt" 2 "adversary/content"

# ── 6. Content-guard fail-closed (no jq in hook) ──
echo "[6/6] Hooks — fail-closed check"
test_hook "$HOOKS_DIR/firewall.sh" '{}' 2 "firewall: empty input -> exit 2 (fail-closed)"
test_hook "$HOOKS_DIR/file-guard.sh" '{}' 2 "file-guard: empty input -> exit 2 (fail-closed)"
test_hook "$HOOKS_DIR/content-guard.sh" '{}' 2 "content-guard: empty input -> exit 2 (fail-closed)"

echo ""
echo "========================================="
echo -e "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "========================================="

if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}FAILURES:${NC}$ERRORS"
  exit 1
fi

echo -e "${GREEN}All conformance tests passed.${NC}"
exit 0
