#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backups/$(date +%Y%m%d_%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Claude Code Harness Installer ==="
echo ""

# 创建备份目录
mkdir -p "$BACKUP_DIR"
mkdir -p "$CLAUDE_DIR/hooks"
mkdir -p "$CLAUDE_DIR/skills"

# 安全复制：如果目标文件已存在，先备份
safe_copy() {
  local src="$1"
  local dst="$2"
  if [ -f "$dst" ]; then
    cp "$dst" "$BACKUP_DIR/$(basename "$dst")"
    echo "  backed up: $dst → $BACKUP_DIR/"
  fi
  cp "$src" "$dst"
  echo "  installed: $dst"
}

echo "--- core/ ---"
safe_copy "$SCRIPT_DIR/core/CRITICAL_RULES.md" "$CLAUDE_DIR/CRITICAL_RULES.md"
safe_copy "$SCRIPT_DIR/core/CLAUDE.md"         "$CLAUDE_DIR/CLAUDE.md"
safe_copy "$SCRIPT_DIR/core/.claudeignore"     "$CLAUDE_DIR/.claudeignore"

echo ""
echo "--- hooks/ ---"
for script in "$SCRIPT_DIR/hooks/"*.sh; do
  safe_copy "$script" "$CLAUDE_DIR/hooks/$(basename "$script")"
  chmod +x "$CLAUDE_DIR/hooks/$(basename "$script")"
done

echo ""
echo "--- skills/ ---"
for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  skill_name=$(basename "$skill_dir")
  mkdir -p "$CLAUDE_DIR/skills/$skill_name"
  safe_copy "$skill_dir/SKILL.md" "$CLAUDE_DIR/skills/$skill_name/SKILL.md"
done

echo ""
echo "--- settings.json merge ---"
SETTINGS="$CLAUDE_DIR/settings.json"
HOOKS_SRC="$SCRIPT_DIR/templates/settings.hooks.json"

if [ -f "$HOOKS_SRC" ]; then
  if command -v jq &>/dev/null; then
    # jq 深度合并：保留 env，注入 hooks
    if [ -f "$SETTINGS" ]; then
      cp "$SETTINGS" "$BACKUP_DIR/settings.json"
      jq -s '.[0] * .[1]' "$SETTINGS" "$HOOKS_SRC" > "$SETTINGS.tmp"
      mv "$SETTINGS.tmp" "$SETTINGS"
      echo "  merged hooks into $SETTINGS (jq)"
    else
      cp "$HOOKS_SRC" "$SETTINGS"
      echo "  created $SETTINGS (no existing settings.json)"
    fi
  else
    echo ""
    echo "  WARNING: jq not found. Cannot auto-merge settings.json."
    echo "  Please manually copy the hooks section from:"
    echo "    $HOOKS_SRC"
    echo "  into:"
    echo "    $SETTINGS"
    echo ""
  fi
else
  echo "  skipped (templates/settings.hooks.json not found)"
fi

echo ""
echo "=== Done ==="
echo "Backups: $BACKUP_DIR"
echo "Restart Claude Code for hooks to take effect."
