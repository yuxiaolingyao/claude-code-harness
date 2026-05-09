#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backups/$(date +%Y%m%d_%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Claude Code Harness Installer ==="

mkdir -p "$BACKUP_DIR" "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/skills"

safe_copy() {
  local src="$1" dst="$2"
  if [ -f "$dst" ]; then
    cp "$dst" "$BACKUP_DIR/$(basename "$dst")"
    echo "  backup: $dst"
  fi
  cp "$src" "$dst"
  echo "  install: $dst"
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

# ── Skills ──
echo "[skills]"
for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  skill_name=$(basename "$skill_dir")
  mkdir -p "$CLAUDE_DIR/skills/$skill_name"
  safe_copy "$skill_dir/SKILL.md" "$CLAUDE_DIR/skills/$skill_name/SKILL.md"
done

# ── Settings 提示 ──
echo ""
echo "=== 手动步骤 ==="
echo "请将以下内容合并到 ~/.claude/settings.json："
echo ""
echo "  如果 settings.json 已存在，在顶层添加 \"hooks\" 字段（与 \"env\" 平级）"
echo "  如果不存在，直接创建，内容如下："
echo ""
cat "$SCRIPT_DIR/templates/settings.hooks.json"
echo ""
echo "=== Done ==="
echo "Backup: $BACKUP_DIR"
echo "Restart Claude Code to apply."
