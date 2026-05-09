#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backups/$(date +%Y%m%d_%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Claude Code Harness Installer ==="
echo ""

# ── Preflight ──
if ! command -v jq >/dev/null 2>&1; then
  echo "[WARN] jq not found. Hooks will block ALL operations (fail-closed)."
  echo "       Install jq to enable hook decision logic:"
  echo "         macOS:  brew install jq"
  echo "         Linux:  apt install jq / yum install jq"
  echo "         Win:    winget install jqlang.jq"
  echo ""
fi

mkdir -p "$BACKUP_DIR" "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/skills" "$CLAUDE_DIR/rules"

safe_copy() {
  local src="$1" dst="$2"
  if [ -f "$dst" ]; then
    cp "$dst" "$BACKUP_DIR/$(basename "$dst")"
    echo "  backup: $dst"
  fi
  cp "$src" "$dst"
  echo "  install: $dst"
}

safe_copydir() {
  local src="$1" dst="$2"
  if [ -d "$dst" ]; then
    cp -r "$dst" "$BACKUP_DIR/$(basename "$dst")"
    echo "  backup: $dst/"
  fi
  mkdir -p "$dst"
  cp -r "$src"/* "$dst/"
  echo "  install: $dst/"
}

# ── Core ──
echo "[core]"
safe_copy "$SCRIPT_DIR/core/CRITICAL_RULES.md" "$CLAUDE_DIR/CRITICAL_RULES.md"
safe_copy "$SCRIPT_DIR/core/CLAUDE.md"         "$CLAUDE_DIR/CLAUDE.md"
safe_copy "$SCRIPT_DIR/core/.claudeignore"     "$CLAUDE_DIR/.claudeignore"

# ── Hooks ──
echo "[hooks]"
for script in "$SCRIPT_DIR/hooks/"*.sh; do
  safe_copy "$script" "$CLAUDE_DIR/hooks/$(basename "$script")"
  chmod +x "$CLAUDE_DIR/hooks/$(basename "$script")"
done

# Remove legacy hooks that were replaced
for legacy in security-firewall.sh sensitive-files.sh; do
  if [ -f "$CLAUDE_DIR/hooks/$legacy" ]; then
    cp "$CLAUDE_DIR/hooks/$legacy" "$BACKUP_DIR/$legacy"
    rm "$CLAUDE_DIR/hooks/$legacy"
    echo "  removed legacy: $CLAUDE_DIR/hooks/$legacy"
  fi
done

# ── Rules ──
echo "[rules]"
safe_copydir "$SCRIPT_DIR/rules" "$CLAUDE_DIR/rules"
# Strip CRLF (Windows compat)
for f in "$CLAUDE_DIR/rules/"*.json "$CLAUDE_DIR/hooks/"*.sh "$CLAUDE_DIR/CRITICAL_RULES.md" "$CLAUDE_DIR/CLAUDE.md"; do
  [ -f "$f" ] && sed -i 's/\r$//' "$f" 2>/dev/null || true
done

# ── Skills ──
echo "[skills]"
for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  skill_name=$(basename "$skill_dir")
  mkdir -p "$CLAUDE_DIR/skills/$skill_name"
  safe_copy "$skill_dir/SKILL.md" "$CLAUDE_DIR/skills/$skill_name/SKILL.md"
done

# ── Integrity checksums ──
echo "[integrity]"
CHECKSUM_FILE="$CLAUDE_DIR/hooks/.checksums"
> "$CHECKSUM_FILE"  # truncate
for f in "$CLAUDE_DIR/hooks/"*.sh "$CLAUDE_DIR/rules/"*.json "$CLAUDE_DIR/CRITICAL_RULES.md" "$CLAUDE_DIR/CLAUDE.md"; do
  [ -f "$f" ] || continue
  sha256sum "$f" >> "$CHECKSUM_FILE" 2>/dev/null || true
done
echo "  generated: $CHECKSUM_FILE ($(wc -l < "$CHECKSUM_FILE") files)"

# ── Mode config (only install if not exists — user preference) ──
echo "[config]"
MODE_FILE="$CLAUDE_DIR/harness-mode.json"
if [ -f "$MODE_FILE" ]; then
  echo "  keep: $MODE_FILE (already exists)"
else
  cp "$SCRIPT_DIR/templates/harness-mode.json" "$MODE_FILE"
  echo "  install: $MODE_FILE"
fi

# ── Tests (not installed to ~/.claude, kept in repo) ──

# ── Smoke test ──
echo ""
echo "[smoke] Running conformance smoke test..."
echo "  Note: if hooks are already active, they may intercept test commands."
echo "  That's expected — it means your firewall is working."
if [ -f "$SCRIPT_DIR/tests/conformance.sh" ]; then
  bash "$SCRIPT_DIR/tests/conformance.sh" 2>&1 | tail -5 || echo "  (smoke test complete)"
else
  echo "  (no conformance test found, skipping)"
fi

# ── Auto-merge settings.json ──
echo ""
echo "[settings]"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
HOOKS_TEMPLATE="$SCRIPT_DIR/templates/settings.hooks.json"

if [ ! -f "$SETTINGS_FILE" ]; then
  # No existing settings — create from template
  cp "$HOOKS_TEMPLATE" "$SETTINGS_FILE"
  echo "  created: $SETTINGS_FILE"
elif command -v jq >/dev/null 2>&1; then
  # Merge: keep existing keys, replace hooks
  merged=$(jq -s '.[0] * {hooks: (.[1].hooks)}' "$SETTINGS_FILE" "$HOOKS_TEMPLATE" 2>/dev/null || true)
  if [ -n "$merged" ]; then
    cp "$SETTINGS_FILE" "$BACKUP_DIR/settings.json"
    echo "$merged" > "$SETTINGS_FILE"
    echo "  merged: hooks into $SETTINGS_FILE (backup: $BACKUP_DIR/settings.json)"
  else
    echo "  WARN: jq merge failed — manually add hooks from templates/settings.hooks.json"
  fi
else
  echo "  SKIP: jq not found — manually add hooks from templates/settings.hooks.json"
fi

echo ""
echo "=== Done ==="
echo "Backup: $BACKUP_DIR"
echo "Restart Claude Code to apply."
