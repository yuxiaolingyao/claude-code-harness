# CVE 响应流程

当 Claude Code 或相关组件披露安全漏洞时，本项目的响应标准操作流程。

---

## 1. 监控

关注以下信息源：

- Anthropic Security Advisories
- Claude Code GitHub Releases
- OWASP ASI 更新
- MITRE ATLAS 更新
- CVE 公告（CVE-2025-59536, CVE-2025-66032, CVE-2025-54794/5, CVE-2025-55284 等）

---

## 2. 评估

对每个相关 CVE：

| 问题 | 判断标准 |
|------|---------|
| 是否影响 Hook 层？ | 攻击向量是否通过 Bash/Write/Edit 工具执行？ |
| 是否影响规则层？ | 现有规则是否能检测此攻击？ |
| 是否需要新模式？ | 攻击是否利用了未被覆盖的命令/文件/内容模式？ |
| 严重度 | 对标 OWASP ASI 的 ASI01-ASI10 |

---

## 3. 复现

在 `tests/adversarial-corpus/` 中新增回归样本：

```bash
# 以 CVE-2025-66032 为例
# 新增文件: tests/adversarial-corpus/bash-bypass.txt
# 包含 8 种已知绕过变体
```

---

## 4. 修复

1. 在 `rules/*.json` 中新增匹配模式
2. 更新对抗样本库
3. 如涉及新模式类别，更新 conformance.sh
4. 更新 THREAT_MODEL.md 覆盖矩阵

---

## 5. 验证

```bash
bash tests/conformance.sh
# 必须 100% 通过
```

---

## 6. 发布

- 语义化版本号递增（PATCH：修复 / MINOR：新增规则类别 / MAJOR：破坏性变更）
- CHANGELOG 记录 CVE 编号和修复内容
- Git tag + push

---

## 已知 CVE 覆盖状态

| CVE | 描述 | 覆盖状态 |
|-----|------|:--:|
| CVE-2025-59536 | 恶意 .claude/settings.json RCE | ⚠️ integrity-check.sh + 建议 allowManagedHooksOnly |
| CVE-2025-66032 | 8 种 Bash denylist 绕过 | ✅ encoding-bypass 规则 + 对抗样本覆盖 |
| CVE-2025-54794/5 | InversePrompt + echo 注入 | ✅ command-injection 规则覆盖 |
| CVE-2025-55284 | DNS exfiltration via tool use | ✅ network-attack 规则 + credential-exfil 规则 |
| CVE-2026-21852 | MCP redirect API key theft | ❌ 待后续版本（MCP 工具调用拦截） |
