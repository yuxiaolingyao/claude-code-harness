# Claude Code Harness

Claude Code 用户级全局质量保障套件。克隆即用，对所有项目统一生效。

## 架构

```
三层防御                   安装目标 (~/.claude/)
─────────────────────────────────────────────────
UserPromptSubmit ──→ CRITICAL_RULES.md   每轮注入（防遗忘）
PreToolUse:Bash  ──→ hooks/security-firewall.sh   拦截危险命令
PreToolUse:Write ──→ hooks/sensitive-files.sh     拦截敏感文件写入
Core             ──→ CLAUDE.md + .claudeignore    基线规则 + 上下文卫生
Skills           ──→ skills/*/SKILL.md            按需触发的领域知识
```

## 安装

```bash
git clone https://github.com/<your-username>/claude-code-harness.git
cd claude-code-harness
bash install.sh
```

install.sh 自动复制所有文件到 `~/.claude/`，同名文件备份到 `~/.claude/backups/`。最后打印 settings.json 要追加的 hooks 段，手动粘贴即可。

> Windows 用户：Claude Code 自带 Git Bash，install.sh 在其中直接运行，无需额外安装任何工具。

## 包含的 Skills

| Skill | 触发 | 功能 |
|-------|------|------|
| `code-review` | `/review` | 通用代码审查（空安全、异常、性能、安全） |
| `simplify` | `/simplify` | 代码精简（冗余、过度抽象、死代码） |
| `security-check` | `/security` | 安全扫描（密钥泄露、注入、路径遍历） |

## 更新

```bash
cd claude-code-harness
git pull
bash install.sh    # 重新安装（已有文件会备份）
```

## 自定义

1. 编辑 `core/CLAUDE.md` 添加语言特定规则
2. 编辑 `core/CRITICAL_RULES.md` 调整问责内容
3. 在 `skills/` 下新增自定义 Skill

## 卸载

```bash
rm ~/.claude/CRITICAL_RULES.md
rm ~/.claude/CLAUDE.md
rm ~/.claude/.claudeignore
rm -rf ~/.claude/hooks/
rm -rf ~/.claude/skills/
# 然后手动编辑 ~/.claude/settings.json 删除 hooks 段
```

## License

MIT
