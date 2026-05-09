# Claude Code Harness

> 确定性脚手架套住概率性模型 —— Harness Engineering 的完整落地实现。

**一键安装，对所有项目统一生效。** 无论后端用 Claude / GPT / DeepSeek / Gemini，防火墙始终在线。

---

## 你得到什么

| 能力 | 说明 |
|------|------|
| 🛡️ **命令防火墙** | 50+ 危险模式（rm -rf /、反弹Shell、凭证泄露、供应链攻击）|
| 🔑 **密钥泄露拦截** | 实时检测写入内容中的 API key、Token、私钥 |
| 🔁 **自验证循环** | 编辑后自动编译，失败即反馈模型修复 |
| 🚨 **反循环哨兵** | 检测暴力重试、编辑死循环、分析瘫痪 |
| 🔒 **完整性校验** | SHA256 校验 Hook 和规则文件，防篡改 |
| 📋 **6 个审查 Skill** | 代码审查 / 安全扫描 / 精简 / 数据库 / 基础设施 / 密钥 |
| 🎛️ **三种模式** | enforce（拦截）/ ask（弹确认框）/ audit（仅日志） |
| 🧪 **对抗测试** | 60+ 对抗样本 + 90+ 误报样本，CI 自动验证 |

---

## 安装

```bash
git clone https://github.com/<your-username>/claude-code-harness.git
cd claude-code-harness
bash install.sh
```

install.sh 自动：复制文件 → 备份旧版 → 合并 settings.json → 生成 SHA256 校验和 → 跑烟雾测试。

```bash
# 需要 jq（唯一依赖）
# macOS:  brew install jq
# Linux:  apt install jq
# Win:    winget install jqlang.jq
```

---

## 架构

```
┌─ Hook 层（bash + 正则，模型无关）────────────────────────┐
│                                                          │
│  PreToolUse:Bash  → firewall.sh      命令防火墙          │
│  PreToolUse:Write → file-guard.sh    敏感文件路径         │
│                     content-guard.sh 敏感内容检测         │
│  SessionStart     → integrity-check  SHA256 校验         │
│                     session-start    注入项目状态         │
│  PostToolUse      → post-format      自动格式化           │
│                     auto-verify      编译验证 ←──┐        │
│                     sentinel         反循环检测   │        │
│  PreCompact       → compact-save     上下文保存   │        │
│  Stop             → prompt 验证      "测试过了吗？"├── 自验证│
│                                                  │   循环 │
├─ 规则层（JSON，本地读取）─────────────┐            │        │
│  dangerous-commands / sensitive-files │            │        │
│  sensitive-content / network-guard    │            │        │
├─ 提示词层（注入到模型上下文）─────────┤            │        │
│  CRITICAL_RULES 每轮注入 / CLAUDE.md ─┘            │        │
│                                                          │
├─ Skill 层（按需触发，大模型审查）─────────────────────────┤
│  /review /security /simplify /db-review /infra-review /secrets │
└──────────────────────────────────────────────────────────┘
```

**确定性递增：** 越往下越依赖模型理解 → 越往上越依赖正则/编译器 → 越往上越可靠。

---

## 三种模式

```bash
# 默认：直接拦截
{"mode":"enforce"}

# 危险操作弹确认框
echo '{"mode":"ask"}' > ~/.claude/harness-mode.json

# 只记日志不拦（调试用）
echo '{"mode":"audit"}' > ~/.claude/harness-mode.json
```

| 模式 | 命中后 | 适合 |
|------|--------|------|
| enforce | deny，Claude 换方案 | Claude / GPT |
| ask | 弹出权限确认框 | DeepSeek / Gemini |
| audit | 只记日志，放行 | 过渡期观察 |

---

## 自验证循环

```
Write/Edit 文件
    ↓
auto-verify.sh: 检测构建系统，跑编译
    ↓
编译失败 → stderr 错误信息 → Claude 看到 → 立即修复
    ↓
编译通过 → Claude 觉得做完了
    ↓
Stop prompt: "测试通过了吗？有未完成的工作吗？"
    ↓
未完成 → continue → Claude 继续工作
已完成 → done → 真正停止
```

支持 Maven / Gradle / Cargo / Go / TypeScript / Node / Make / Python。

---

## 多模型

**Hook 层是纯 bash，换任何模型都同样拦截。**

CLAUDE.md 用原则而非指令（跨模型通用）。模型细节见 `docs/MODEL_NOTES.md`：

- Claude/GPT：enforce 模式
- DeepSeek/Gemini：建议 ask 模式（tool calling 精度差异）
- Skill 审查：弱模型上建议切 Claude 执行

---

## 项目结构

```
├── install.sh              一键安装
├── hooks/                   8 个 Hook 脚本（bash + jq）
├── rules/                   4 个 JSON 规则文件
├── skills/                  6 个审查 Skill
├── core/                    CLAUDE.md + CRITICAL_RULES.md
├── templates/               settings.hooks.json + harness-mode.json
├── tests/                   对抗语料 + 误报语料 + conformance.sh
├── docs/                    UPGRADE / THREAT_MODEL / CVE_RESPONSE / MODEL_NOTES
└── .github/workflows/       CI 自动测试
```

---

## 测试

```bash
bash tests/conformance.sh
```

- 对抗样本 60+：bash 绕过、凭证泄露、反弹Shell、命令注入、编码绕过
- 误报样本 90+：合法开发命令、安全文件路径
- 每次 PR 自动跑 CI

---

## 更新 & 卸载

```bash
# 更新
git pull && bash install.sh

# 卸载
rm ~/.claude/CRITICAL_RULES.md ~/.claude/CLAUDE.md ~/.claude/.claudeignore ~/.claude/harness-mode.json
rm -rf ~/.claude/hooks/ ~/.claude/rules/ ~/.claude/skills/
# 手动编辑 ~/.claude/settings.json 删除 hooks 段
```

---

## License

MIT
