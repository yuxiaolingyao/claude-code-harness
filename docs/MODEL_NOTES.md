# 多模型适配说明

Hook 层（firewall / file-guard / content-guard）是纯 Bash + 正则，**与后端模型无关**——换任何模型都同样拦截。
CLAUDE.md 和 Skill 是注入到模型上下文的提示词，不同模型遵循程度不同。

---

## 模型能力对照

| 模型 | Tool Calling | 指令遵循 | 代码审查 | 建议 max_steps |
|------|:---:|:---:|:---:|:---:|
| Claude Sonnet 4 / Opus 4 | ★★★★★ | ★★★★★ | ★★★★★ | 200 |
| GPT-4o / GPT-5.4 | ★★★★★ | ★★★★ | ★★★★ | 200 |
| DeepSeek V3 / V4 | ★★★★ | ★★★ | ★★★ | 100 |
| Gemini 2.0 Flash | ★★★★ | ★★★ | ★★★ | 80 |
| Qwen3-Coder | ★★★ | ★★ | ★★ | 50 |
| Llama 3.3 70B | ★★ | ★★ | ★★ | 50 |

---

## 按模型推荐配置

### Claude Sonnet 4 / Opus 4（默认）

```json
{"mode": "enforce"}
```

CLAUDE.md 完整生效，Skill 直接用。可靠度最高。

### GPT-4o / GPT-5.4

```json
{"mode": "enforce"}
```

指令遵循接近 Claude。CLAUDE.md 规则大概率被遵循，偶有遗漏由 Hook 兜底。
Skill 审查质量与 Claude 接近。

### DeepSeek V3 / V4

```json
{"mode": "ask"}
```

Tool calling 准确率约 80%，建议 ask 模式——Hook 拦截危险命令后弹确认框，用户最终裁决。
CLAUDE.md 的"授权门禁"可能被部分忽视，CRITICAL_RULES 每轮注入尤其重要。
Skill 审查不如 Claude 深入，复杂项目建议切 Claude 做最终审查。

### Gemini 2.0 Flash

```json
{"mode": "ask"}
```

速度极快但推理深度不足。适合日常编码，不适合 `/review`。
建议 /review 和 /security 切 Claude 执行。

### 本地模型（Llama / Qwen 等）

```json
{"mode": "ask"}
```

Tool calling 弱，CLAUDE.md 遵循度低。**强制 ask 模式**，所有危险操作必须人工确认。
不适合代码审查类 Skill。

---

## Skill 模型选择

Skill 的 SKILL.md frontmatter 使用 `model: auto`（跟随 settings.json 全局设置）：

```yaml
model: auto
```

如需特定 Skill 强制用强模型（如 /review），可在项目 `.claude/settings.local.json` 覆盖：

```json
{
  "skills": {
    "code-review": { "model": "sonnet" }
  }
}
```

---

## CLAUDE.md 原则适配

本项目的 CLAUDE.md 以"原则"为主（跨模型通用）：

| 原则 | 弱模型适配 |
|------|-----------|
| 禁止假设 API 签名 | DeepSeek/Qwen 可能偶尔违反，但不会造成安全后果（Hook 兜底） |
| 五阶段强制流 | 弱模型可能跳过步骤，建议打开 ask 模式 |
| 授权门禁 | 弱模型可能忽视，CRITICAL_RULES 每轮注入加固 |
| 禁止 force push main | firewall.sh 直接拦截，不依赖模型遵循 |

**规则越接近 Hook 层越可靠，越依赖模型遵循越不可靠。** 核心安全策略都落在 Hook 层就是这个原因。
