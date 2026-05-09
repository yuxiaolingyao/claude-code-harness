# Claude Code Harness 升级方案

> 从 v0.1.0 → v1.0.0 的完整演进路径。目标用户：个人开发者 + 中小型企业内部团队。
> 最后更新：2026-05-09

## 当前版本：v1.0.0-rc

Phase 1–4 已全部实施完成，额外增加哨兵反循环检测 + settings.json 自动合并 + 多模型适配。
详见下方"已实施 vs 规划"对照。

---

## 横向对比（2026.5 与主流开源项目）

| 维度 | Harness | CC Cortex | arthus-harness | ai-hooks | Matt Pocock | Redpanda |
|------|:--:|:--:|:--:|:--:|:--:|:--:|
| Hook 防火墙 | ✅ 50+ | ✅ 40+ | ✅ 3 | ✅ 4 | ⚠️ git | ✅ |
| 敏感内容检测 | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| 文件完整性 SHA256 | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| 自验证循环 | ✅ | ❌ | ❌ | ❌ | ⚠️ tdd | ✅ |
| 反循环哨兵 | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| 模式切换 enforce/ask/audit | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Skills | 6 | ❌ | 4 | ❌ | 23+ | 1 |
| 对抗测试 | ✅ 60+/90+ | ❌ | ❌ | ❌ | ❌ | ❌ |
| 威胁模型 | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| 多模型文档 | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| 安装方式 | bash install.sh | pip install | npx create | npm install | npx skills | git clone |
| settings 自动合并 | ✅ | — | — | — | — | ✅ |
| 多工具支持 | ❌ | ❌ | ❌ | ✅ 9+ | ❌ | ❌ |
| npm 分发 | ❌ | ✅ PyPI | ✅ | ✅ | ✅ | ❌ |

### 本项目独有优势

- 对抗测试体系（60+ 对抗样本 + 90+ 误报样本 + CI 自动验证）
- SHA256 文件完整性校验
- 完整威胁模型文档（OWASP ASI 2026 + MITRE ATLAS）
- 多模型适配指南

### 已知差距（不在当前路线图）

- npm 分发（用户需 git clone）
- 多 AI 工具统一配置（仅支持 Claude Code）
- 丰富的社区 Skill 生态（仅 6 个内置 Skill）

---

## 已实施 vs 原规划对照

| 规划项 | 状态 |
|--------|:--:|
| fail-closed 防火墙 | ✅ |
| JSON 规则分离 | ✅ |
| content-guard 内容检测 | ✅ |
| 对抗测试 + CI | ✅ |
| enforce/ask/audit 三模式 | ✅ |
| SHA256 完整性校验 | ✅ |
| 自验证循环 auto-verify | ✅ |
| 反循环哨兵 sentinel | ✅ |
| settings.json 自动合并 | ✅ |
| 多模型适配 MODEL_NOTES | ✅ |
| 3 个新 Skill（db/infra/secrets） | ✅ |
| 威胁模型 + CVE 响应文档 | ✅ |
| npm 分发 | 🔵 后续考虑 |

---

## 目录

1. [为什么升级](#1-为什么升级)
2. [对标分析](#2-对标分析)
3. [目标架构](#3-目标架构)
4. [逐 Phase 实施](#4-逐-phase-实施)
5. [迁移指南](#5-迁移指南)
6. [测试策略](#6-测试策略)

---

## 1. 为什么升级

### 当前版本的核心缺陷

| 问题 | 严重度 | 影响 |
|------|:------:|------|
| **Fail-open**：jq 不可用时静默放行所有命令 | 🔴 Critical | 防火墙形同虚设。OACB、guardian、Captain Hook 全部 fail-closed |
| **11 条危险模式**覆盖不足 | 🔴 Critical | 缺少反向Shell、base64注入、凭证泄露、metadata端点等关键攻击面。CVE-2025-66032 已有 8 种已知绕过 |
| **无对抗验证** | 🟠 High | 没有绕过样本库，无法知道规则是否真的有效 |
| **无密钥/凭证检测** | 🟠 High | `.env` 文件路径是拦了，但 `echo "API_KEY=xxx" > foo.txt` 拦不住 |
| **硬编码规则** | 🟡 Medium | 规则写在 shell 脚本里，更新要改代码，无法独立维护 |
| **Hook 事件不全** | 🟡 Medium | 缺少 PostToolUse（自动格式化）、PreCompact（上下文保存）、SessionStart（状态注入） |
| **Skills 太少** | 🟢 Low | 仅 3 个通用 skill，缺少 DB/Infra/Auth 等高频风险领域 |
| **无审计** | 🟠 High | 无法回溯谁/何时做了什么操作，合规场景完全缺失 |

### 安全形势变化

2025-2026 年 Claude Code 已披露的高危 CVE：

| CVE | 攻击向量 | 本项目应对 |
|-----|----------|-----------|
| CVE-2025-59536 | 恶意 repo 的 `.claude/settings.json` RCE | Hook 脚本签名校验 |
| CVE-2025-66032 | 8 种 Bash denylist 绕过 | 对抗语料覆盖全部 8 种 |
| CVE-2025-54794/5 | 逆向 Prompt + echo 命令注入 | 路径注入检测 + 命令拼接检测 |
| CVE-2025-55284 | DNS 泄露 via 工具调用 | 网络层规则 |
| CVE-2026-21852 | MCP 重定向偷 API key | MCP 工具调用拦截 |

---

## 2. 对标分析

### 现有主流方案的启示

| 项目 | 值得借鉴 | 不适合借鉴 | 启示 |
|------|---------|-----------|------|
| **OACB** | fail-closed Hook、对抗语料+误报语料、OWASP ASI 威胁模型映射、一致性测试框架 | 4 档分级（paranoid 档的网络层拦截超出本项目边界） | **安全规则的严肃性来自测试，不是配置档位数量** |
| **@rezzed.ai/guardian** | SHA256 链式审计、密钥检测（正则+熵）、预算管控、50+ 模式 5 类别 | npm 强依赖（本项目保持零依赖可独立安装） | **审计链是合规刚需，不是可选功能** |
| **Captain Hook** | YAML 策略引擎（allow/deny 显式决策）、PreToolUse 确定性门禁 | YAML 解析依赖 Python/Ruby，增加依赖 | **策略应声明式配置，不是脚本逻辑** |
| **nyolo** | ESLint 风格 flat config、35 条推荐默认 | 聚焦权限绕过，覆盖面窄 | **"默认全开，可显式关闭"优于"默认关闭，手动开启"** |
| **Droidzold/hardened-security-config** | 管道注入防护、逆向 Shell 检测、base64 载荷拦截 | Windows 特化、ClawRuleBook 耦合 | **命令模式必须覆盖二层攻击（拼接、编码、管道）** |
| **Warden Core** | 幻影包检测（AI 编造的包名）、污点追踪 | 混合 AI 引擎成本高，不适合轻量定位 | **供应链安全是 AI 编码的独特风险面** |
| **Claude Code 原生权限** | 内置 deny/ask/allow、托管配置 MDM 下发 | 纯文本匹配可绕过（`python -c "print(open('.env').read())"` 绕过 `deny: Bash(cat .env)`） | **原生权限是防御第一层，但需要 Hook 层补充复杂判定** |

### 核心结论

**所有成熟方案都在做同一件事：把安全规则从"建议"变成"可验证的强制执行"。** 区别仅在于实现层次：

```
建议层 (CLAUDE.md) ──→ 权限层 (deny/ask/allow) ──→ Hook层 (fail-closed 脚本) ──→ 网络/内核层 (沙箱/网关)
 ←── 本项目 v0.1.0 停在这里 ──→  ←── 本项目 v1.0.0 到达这里 ──→   ←── 企业额外部署 ──→
```

v0.1.0 只有 CLAUDE.md 注入 + 两个 fail-open Hook。v1.0.0 要把 Hook 层做完整。

---

## 3. 目标架构

### 设计原则

1. **安全规则不分级** — 破坏性命令/密钥泄露/供应链投毒对个人和团队同样危险，一套规则覆盖所有人
2. **一个开关** — `enforce`（默认，拦截）/ `audit`（仅日志告警，调试用），不设更多模式
3. **零依赖安装** — `install.sh` 仅需 bash + jq（预检），无 Node.js/Python 依赖
4. **规则与执行分离** — 规则存 JSON 文件，Hook 脚本只做通用匹配引擎
5. **测试驱动安全** — 每条规则必须对应对抗样本（必须拦截）和误报样本（必须放行）

### 目录结构

```
claude-code-harness/
├── install.sh                        # 一键安装（预检 jq，安装标准配置）
│
├── core/                             # 规则注入层
│   ├── CRITICAL_RULES.md             # ≤30行，UserPromptSubmit 每轮注入
│   ├── CLAUDE.md                     # 编码规约基线（全局适用）
│   └── .claudeignore                 # 上下文卫生（减少 token 浪费）
│
├── hooks/                            # 强制执行层（全部 fail-closed）
│   ├── firewall.sh                   # PreToolUse:Bash → 命令防火墙
│   ├── file-guard.sh                 # PreToolUse:Write|Edit → 敏感路径拦截
│   ├── content-guard.sh              # PreToolUse:Write|Edit → 敏感内容拦截（密钥泄露）
│   ├── post-format.sh                # PostToolUse:Write|Edit → 自动格式化
│   ├── compact-save.sh              # PreCompact → 保存关键上下文
│   └── session-start.sh             # SessionStart → 注入项目状态
│
├── rules/                            # 策略配置（JSON，Hook 运行时读取）
│   ├── dangerous-commands.json       # 命令防火墙规则
│   ├── sensitive-files.json          # 敏感文件路径模式
│   ├── sensitive-content.json        # 敏感内容检测模式（密钥/Token/PII）
│   └── network-guard.json            # 网络地址防护（metadata端点/SSRF）
│
├── skills/                           # 领域知识层
│   ├── code-review/SKILL.md          # 通用代码审查
│   ├── security-check/SKILL.md       # 安全漏洞扫描
│   ├── simplify/SKILL.md             # 代码精简
│   ├── db-safety/SKILL.md            # 数据库操作安全（DDL/DML 拦截审查）
│   ├── infra-guard/SKILL.md          # 基础设施安全（terraform/k8s/CI 变更审查）
│   └── secrets-leak/SKILL.md         # 密钥泄露深度扫描
│
├── tests/                            # 测试体系
│   ├── conformance.sh                # 一致性测试入口
│   ├── adversarial-corpus/           # 对抗样本（必须拦截）
│   │   ├── bash-bypass.txt           # Bash denylist 绕过（CVE-2025-66032）
│   │   ├── credential-exfil.txt     # 凭证泄露
│   │   ├── reverse-shell.txt        # 反弹 Shell
│   │   ├── command-injection.txt    # 命令注入
│   │   └── path-traversal.txt       # 路径遍历
│   └── false-positive-corpus/       # 误报样本（必须放行）
│       ├── legitimate-commands.txt  # 正常开发命令
│       └── safe-file-paths.txt      # 正常文件操作
│
├── templates/
│   └── settings.hooks.json           # 完整 Hook 配置参考
│
├── docs/
│   ├── UPGRADE.md                    # 本文件
│   ├── THREAT_MODEL.md               # OWASP ASI 2026 + MITRE ATLAS 映射
│   └── CVE_RESPONSE.md               # CVE 响应流程
│
├── .github/workflows/
│   └── conformance.yml               # CI：每次 PR 运行对抗测试
│
├── CLAUDE.md                         # 项目自身规约
├── README.md
└── .gitignore
```

### Hook 事件全景

| 事件 | Hook | 功能 |
|------|------|------|
| **UserPromptSubmit** | `cat CRITICAL_RULES.md` | 每轮注入安全准则 |
| **SessionStart** | `session-start.sh` | 注入项目 git 状态、TODO |
| **PreToolUse:Bash** | `firewall.sh` | 命令防火墙（50+ 危险模式） |
| **PreToolUse:Write\|Edit** | `file-guard.sh` | 敏感文件路径拦截 |
| **PreToolUse:Write\|Edit** | `content-guard.sh` | 写入内容检测（密钥/Token/PII） |
| **PostToolUse:Write\|Edit** | `post-format.sh` | 自动格式化（prettier/eslint） |
| **PreCompact** | `compact-save.sh` | 压缩前保存关键上下文 |

---

## 4. 逐 Phase 实施

### Phase 1：推倒重来 — 安全核心（v0.2.0）

**目标**：把 fail-open 的 11 条规则，换成 fail-closed 的 50+ 条规则 + 对抗测试。

#### 4.1.1 firewall.sh（重写）

核心改动：
- 规则从脚本硬编码移到 `rules/dangerous-commands.json` 外部配置
- jq 不可用时 **exit 2**（fail-closed）
- 分类覆盖：破坏性命令 / 凭证泄露 / 反弹Shell / 编码绕过 / 网络攻击 / 供应链

`rules/dangerous-commands.json` 结构：

```json
{
  "version": "1.0.0",
  "categories": {
    "destructive": {
      "description": "不可逆破坏性操作",
      "patterns": []
    },
    "credential-exfil": {
      "description": "凭证/密钥泄露",
      "patterns": []
    },
    "reverse-shell": {
      "description": "反弹Shell及远程代码执行",
      "patterns": []
    },
    "encoding-bypass": {
      "description": "编码/拼接绕过（base64、hex、eval）",
      "patterns": []
    },
    "network-attack": {
      "description": "内网探测/metadata端点/SSRF",
      "patterns": []
    },
    "supply-chain": {
      "description": "供应链攻击（可疑registry、恶意安装源）",
      "patterns": []
    }
  }
}
```

覆盖 50+ 模式（对标 guardian 50+ / nyolo 35）：

| 类别 | 覆盖项 | 示例 |
|------|--------|------|
| destructive | rm -rf /、dd、mkfs、chmod 777、git reset --hard、git push --force main/master、terraform destroy | 全部保留原有 + 补充 terraform/k8s |
| credential-exfil | cat .env、echo $API_KEY、read+print secrets | 新增整类 |
| reverse-shell | nc -e、bash -i >& /dev/tcp、python socket、curl pipe sh | 参考 Droidzold |
| encoding-bypass | base64 -d、eval、python -c exec、xxd | CVE-2025-66032 全部 8 种 |
| network-attack | 169.254.169.254、metadata.google.internal、/etc/passwd | 参考 guardian SSRF |
| supply-chain | pip install from URL、npm --registry unknown、curl | sh | 参考 guardian |

#### 4.1.2 file-guard.sh（重写）

- 规则移至 `rules/sensitive-files.json`
- 扩展敏感文件模式（7→20+）：

| 类别 | 模式 |
|------|------|
| 密钥文件 | `.env`, `.env.*`, `*.pem`, `*.key`, `*.pfx`, `*.p12`, `id_rsa*`, `*.jks` |
| 凭证目录 | `.ssh/`, `.aws/`, `.gcp/`, `.azure/`, `.config/gcloud/` |
| 配置泄露 | `.netrc`, `.htpasswd`, `secrets.yaml`, `credentials.json` |
| 自身保护 | `CRITICAL_RULES.md`, Hook 脚本自身 |

#### 4.1.3 content-guard.sh（新增）

**v0.1.0 没有这层防护。** `file-guard.sh` 只拦 `.env` 文件名，拦不住：
```bash
echo "API_KEY=sk-abc123" > innocuous.md
```

`rules/sensitive-content.json` 检测写入内容中的模式：

| 类型 | 检测模式 | 说明 |
|------|---------|------|
| API Key | `sk-[a-zA-Z0-9]{32,}` | OpenAI 风格 |
| AWS Key | `AKIA[A-Z0-9]{16}` | AWS Access Key ID |
| GitHub Token | `ghp_[a-zA-Z0-9]{36}` | GitHub Personal Token |
| 私钥头 | `-----BEGIN (RSA\|EC\|OPENSSH\|DSA) PRIVATE KEY-----` | PEM 格式私钥 |
| JWT | `eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+` | JWT Token |
| 连接串 | `(mongodb\|mysql\|postgres\|redis)://[^@]+@` | 含凭证的数据库连接串 |
| 高熵值 | Shannon entropy > 4.5 的 20+ 字符段 | 通用密钥/Token 启发式 |

实现注意事项：
- 只拦截**新增**的敏感内容（通过对比 stdin 中的 `new_content` 与文件当前内容），避免文件已存在的合法密钥被误拦
- 熵检测设白名单：base64 公钥、UUID、hash 值等常见高熵但非敏感字符串

#### 4.1.4 对抗测试体系

```
tests/
├── conformance.sh                    # 自动化测试脚本
├── adversarial-corpus/
│   ├── bash-bypass.txt               # 8 种 CVE-2025-66032 绕过（必须全部拦截）
│   ├── credential-exfil.txt         # 20+ 凭证泄露变种（必须全部拦截）
│   ├── reverse-shell.txt            # 10+ 反弹Shell 变种（必须全部拦截）
│   ├── command-injection.txt        # 10+ 命令注入变种（必须全部拦截）
│   └── encoding-bypass.txt          # 10+ 编码绕过变种（必须全部拦截）
└── false-positive-corpus/
    ├── legitimate-commands.txt      # 50+ 正常开发命令（必须全部放行）
    └── safe-file-paths.txt          # 30+ 正常文件路径（必须全部放行）
```

`conformance.sh` 核心逻辑：

```bash
# 对每个 Hook，逐一喂入对抗样本，检查 exit code
# 对抗样本 → 期望 exit 2（拦截）
# 误报样本 → 期望 exit 0（放行）

PASS=0; FAIL=0
for cmd in $(cat adversarial-corpus/*.txt); do
  echo "{\"tool_input\":{\"command\":\"$cmd\"}}" | bash hooks/firewall.sh
  if [ $? -eq 2 ]; then ((PASS++)); else echo "MISS: $cmd"; ((FAIL++)); fi
done
echo "Result: ${PASS} blocked, ${FAIL} missed"
```

`.github/workflows/conformance.yml`：每次 PR 自动跑，任何拦截失败或误报 → CI 失败。

#### 4.1.5 install.sh 改动

- 安装前预检 jq：`command -v jq >/dev/null || echo "[WARN] jq not found, some hooks will reject all operations"`
- 安装后自动运行 `conformance.sh --smoke` 验证 Hook 可用性
- 当前已有备份逻辑保持不变

---

### Phase 2：规则扩展 — 审计 + 格式化 + 上下文（v0.3.0）

#### 4.2.1 post-format.sh（新增 PostToolUse Hook）

Write/Edit 操作后自动运行代码格式化。检测项目是否有对应配置文件决定是否执行：

```bash
# 检测规则（按优先级）：
# .prettierrc* / .eslintrc* / .rubocop.yml / Cargo.toml / gofmt / terraform fmt
# 无一匹配时跳过，不报错
```

#### 4.2.2 compact-save.sh（新增 PreCompact Hook）

Claude Code 长会话会压缩上下文，可能导致任务状态丢失。压缩前保存：

- 当前 git diff（变更摘要）
- 任务列表中未完成项
- `C:\Users\yulingxiaoyao\.claude\projects\{project}\memory\` 的关键记忆指针

保存位置：`.claude/compact-backups/$(date +%Y%m%d_%H%M%S).json`

#### 4.2.3 session-start.sh（新增 SessionStart Hook）

会话启动时自动注入：

- `git status --short`（当前变更）
- `git log -3 --oneline`（最近提交）
- TODO.md / plan 文件内容（如果存在）

#### 4.2.4 审计日志（firewall.sh + file-guard.sh + content-guard.sh 内嵌）

所有 PreToolUse Hook 的拦截判定写入审计日志：

```jsonl
{"ts":"2026-05-09T14:32:01Z","hook":"firewall","decision":"block","rule":"destructive/rm-rf-root","input":"rm -rf /usr/local/foo","reason":"matched pattern: rm\\s+(-[a-z]*r[a-z]*f)"}
{"ts":"2026-05-09T14:32:05Z","hook":"content-guard","decision":"block","rule":"credential/aws-key","input":"...","reason":"matched pattern: AKIA..."}
{"ts":"2026-05-09T14:32:10Z","hook":"firewall","decision":"allow","rule":"*","input":"npm test"}
```

日志位置：`~/.claude/logs/audit.jsonl`

日志轮转策略：单文件 >10MB 或 >30 天后自动归档。

---

### Phase 3：Skills 扩展（v0.4.0）

#### 4.3.1 db-safety/SKILL.md

数据库操作专项审查。触发词：`DROP TABLE`, `ALTER TABLE`, `TRUNCATE`, `DELETE FROM`, `migrate`, `drizzle-kit push`

审查维度：
- DDL 是否包含 CASCADE/DROP
- DML 是否缺少 WHERE 子句
- 迁移是否先备份
- 是否在 production 环境执行

#### 4.3.2 infra-guard/SKILL.md

基础设施变更专项审查。触发词：`terraform destroy`, `kubectl delete`, `helm uninstall`, `docker rm`

审查维度：
- 是否确认了 context/namespace
- terraform destroy 是否限制了 target
- 是否有回滚方案
- 是否涉及生产环境

#### 4.3.3 secrets-leak/SKILL.md

密钥泄露深度扫描（比 content-guard.sh 更深入的静态分析）。触发：`/security`

覆盖 `security-check/SKILL.md` 的密钥部分，两者分工：
- `security-check` → 通用安全漏洞（注入、权限、加密）
- `secrets-leak` → 专注密钥/凭证生命周期

#### 4.3.4 现有 skill 增强

| skill | 改动 |
|-------|------|
| `code-review` | 不变，已较完善 |
| `security-check` | 去掉密钥检测部分（转移到 secrets-leak），聚焦注入/XSS/权限/加密 |
| `simplify` | 不变，已较完善 |

---

### Phase 4：文档 + CI（v1.0.0）

#### 4.4.1 THREAT_MODEL.md

以 OWASP ASI 2026 为框架，逐项标注本项目覆盖情况：

| OWASP ASI | 威胁 | 本项目覆盖 |
|-----------|------|-----------|
| ASI01 | Goal Hijack（Prompt注入） | CRITICAL_RULES.md 每轮注入加固预期行为 |
| ASI02 | Tool Misuse（Bash绕过） | firewall.sh 50+ 模式 + 对抗语料验证 |
| ASI03 | Identity Abuse | ❌ 不覆盖（需平台层解决） |
| ASI04 | Supply Chain | supply-chain 类别规则 |
| ASI05 | Unexpected Code Exec | encoding-bypass 规则 + file-guard 自保护 |
| ASI06 | Context Poisoning | .claudeignore 上下文卫生 |
| ASI09 | Trust Exploitation | CRITICAL_RULES.md 授权门禁 |

同时映射 MITRE ATLAS v5.4.0 相关战术。

#### 4.4.2 CVE_RESPONSE.md

CVE 响应流程文档：
1. 监控：Claude Code Security Advisories + Anthropic 公告
2. 评估：是否影响 Hook 层 / 规则层 / Skills
3. 复现：在 tests/adversarial-corpus 中新增回归样本
4. 修复：更新规则/脚本
5. 验证：conformance.sh 确认修复有效
6. 发布：版本号 + CHANGELOG

#### 4.4.3 CI 工作流

```yaml
# .github/workflows/conformance.yml
name: Conformance Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run conformance tests
        run: bash tests/conformance.sh --strict
```

---

## 5. 迁移指南

### 从 v0.1.0 迁移到 v1.0.0

```bash
# 1. 拉取新版本
cd claude-code-harness
git pull origin master

# 2. 重新安装（旧文件自动备份到 ~/.claude/backups/）
bash install.sh

# 3. 更新 settings.json hooks 段
# 用 templates/settings.hooks.json 的内容替换旧的 hooks 段

# 4. 验证安装
bash tests/conformance.sh --smoke

# 5. 重启 Claude Code
```

### 从旧版 settings.json 迁移

旧版 Hook 配置只有 4 个事件，新版增加到 7 个。需手动合并：

```diff
{
  "hooks": {
    "UserPromptSubmit": [{ ... }],     // 保持不变
    "PreToolUse": [
      { "matcher": "Bash",       ... },  // firewall.sh（新版）
      { "matcher": "Write|Edit", ... },  // file-guard.sh（新版）
      { "matcher": "Write|Edit", ... }   // content-guard.sh（新增）
    ],
+   "PostToolUse": [
+     { "matcher": "Write|Edit", ... }   // post-format.sh（新增）
+   ],
+   "SessionStart": [
+     { "matcher": "startup",    ... }   // session-start.sh（新增）
+   ],
+   "PreCompact": [
+     { "matcher": "",           ... }   // compact-save.sh（新增）
+   ],
    "Stop": [{ ... }]                    // 保持不变
  }
}
```

### 审计日志查询示例

```bash
# 查看最近拦截
tail -100 ~/.claude/logs/audit.jsonl | jq 'select(.decision == "block")'

# 按类别统计
cat ~/.claude/logs/audit.jsonl | jq -r '.rule' | sort | uniq -c | sort -rn

# 查看某时间段
cat ~/.claude/logs/audit.jsonl | jq 'select(.ts >= "2026-05-01")'
```

---

## 6. 测试策略

### 测试金字塔

```
        ┌──────────────┐
        │  CI 集成测试   │  ← conformance.yml: 每次 PR 全量跑
        ├──────────────┤
        │  Smoke 测试   │  ← install.sh 安装后自动跑
        ├──────────────┤
        │  对抗/误报语料  │  ← tests/ 目录下持续增长的样本库
        └──────────────┘
```

### 样本库维护

- **对抗样本**：每发现一个新的绕过手法或 CVE，立即新增样本到 `adversarial-corpus/`
- **误报样本**：每次在真实使用中遇到合法命令被误拦，确认后加入 `false-positive-corpus/`
- **质量门禁**：PR 必须通过全部对抗+误报测试才能合并

### 测试覆盖目标

| 阶段 | 对抗样本数 | 误报样本数 | 目标覆盖率 |
|------|:-------:|:-------:|:--------:|
| v0.2.0 | 60+ | 80+ | 100% |
| v0.3.0 | 80+ | 100+ | 100% |
| v1.0.0 | 100+ | 120+ | 100% |

---

## 变更清单（v0.1.0 → v1.0.0）

### 新增文件（23 个）

| 文件 | 用途 |
|------|------|
| `rules/dangerous-commands.json` | 命令防火墙规则 |
| `rules/sensitive-files.json` | 敏感文件路径规则 |
| `rules/sensitive-content.json` | 敏感内容检测规则 |
| `rules/network-guard.json` | 网络地址防护规则 |
| `hooks/content-guard.sh` | 写入内容检测 |
| `hooks/post-format.sh` | 自动格式化 |
| `hooks/compact-save.sh` | 上下文压缩保护 |
| `hooks/session-start.sh` | 会话启动状态注入 |
| `skills/db-safety/SKILL.md` | 数据库安全 |
| `skills/infra-guard/SKILL.md` | 基础设施安全 |
| `skills/secrets-leak/SKILL.md` | 密钥泄露扫描 |
| `tests/conformance.sh` | 一致性测试入口 |
| `tests/adversarial-corpus/bash-bypass.txt` | CVE-2025-66032 绕过样本 |
| `tests/adversarial-corpus/credential-exfil.txt` | 凭证泄露样本 |
| `tests/adversarial-corpus/reverse-shell.txt` | 反弹Shell样本 |
| `tests/adversarial-corpus/command-injection.txt` | 命令注入样本 |
| `tests/adversarial-corpus/encoding-bypass.txt` | 编码绕过样本 |
| `tests/false-positive-corpus/legitimate-commands.txt` | 合法命令误报样本 |
| `tests/false-positive-corpus/safe-file-paths.txt` | 合法路径误报样本 |
| `.github/workflows/conformance.yml` | CI 自动测试 |
| `docs/UPGRADE.md` | 本文件 |
| `docs/THREAT_MODEL.md` | 威胁模型文档 |
| `docs/CVE_RESPONSE.md` | CVE 响应流程 |

### 重写文件（5 个）

| 文件 | 改动 |
|------|------|
| `hooks/firewall.sh` | 硬编码→JSON规则、fail-open→fail-closed、11→50+模式、增加审计日志 |
| `hooks/file-guard.sh` | 硬编码→JSON规则、fail-open→fail-closed、7→20+模式、增加审计日志 |
| `install.sh` | 新增 jq 预检、smoke 测试、rules/ 安装 |
| `README.md` | 更新架构描述、安装说明、新增 Hook 事件 |
| `skills/security-check/SKILL.md` | 重新分工，移除密钥部分 |

### 不变文件（5 个）

| 文件 | 原因 |
|------|------|
| `core/CRITICAL_RULES.md` | 已在 30 行以内，内容不需改 |
| `core/CLAUDE.md` | 编码规约基线不变 |
| `core/.claudeignore` | 上下文卫生模式不需改 |
| `skills/code-review/SKILL.md` | 已较完善 |
| `skills/simplify/SKILL.md` | 已较完善 |

### 删除文件（1 个）

| 文件 | 原因 |
|------|------|
| `hooks/security-firewall.sh` | 被 `hooks/firewall.sh` 替代（重命名+重写） |

---

## 下一步

Phase 1 开始前需要你确认：

1. 整体架构是否同意？特别是 rules/ JSON 外部配置、fail-closed、3 Hook 分工（命令+文件路径+文件内容）
2. npm 包分发放在 Phase 3 还是砍掉？当前方案靠 `git clone + bash install.sh` 即可完成安装，npm 的好处是版本管理和 `npx` 体验
3. 网络层规则（network-guard.json）是否要？当前划在 Phase 1，但它的实用场景主要是拦截 metadata 端点和 SSRF，个人用户很少遇到
