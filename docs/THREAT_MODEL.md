# 威胁模型

基于 OWASP Top 10 for Agentic Applications 2026 (ASI01–ASI10) 和 MITRE ATLAS v5.4.0。

---

## 覆盖矩阵

| OWASP ASI | 威胁 | 本项目覆盖 | 方式 |
|-----------|------|:--:|------|
| ASI01 | Goal Hijack（Prompt 注入劫持目标） | ⚠️ | CRITICAL_RULES 每轮注入加固预期行为；Hook 层不通过模型判断 |
| ASI02 | Tool Misuse（工具滥用/绕过） | ✅ | firewall.sh 50+ 模式 + 对抗语料验证 |
| ASI03 | Identity & Privilege Abuse | ❌ | 需平台层解决（OS 权限/沙箱） |
| ASI04 | Supply Chain Compromise | ✅ | supply-chain 类别规则拦截恶意 registry/下载源 |
| ASI05 | Unexpected Code Execution | ✅ | encoding-bypass 规则 + file-guard 自保护 + SHA256 完整性校验 |
| ASI06 | Context Poisoning | ⚠️ | .claudeignore 上下文卫生；PreCompact 保存关键状态 |
| ASI07 | Excessive Agency | ⚠️ | max_steps 限制建议（MODEL_NOTES.md）；mode=ask 保留人类决策 |
| ASI08 | Memory/State Manipulation | ⚠️ | integrity-check.sh 校验文件完整性 |
| ASI09 | Human-Agent Trust Exploitation | ✅ | CRITICAL_RULES 授权门禁；ask 模式强制人工确认危险操作 |
| ASI10 | Multi-Agent Collusion | ❌ | 本项目不涉及多 Agent 场景 |

## MITRE ATLAS 映射

| ATLAS Tactic | 覆盖 |
|-------------|:--:|
| Reconnaissance | ✅ network-attack 规则拦截 nmap/masscan/SSRF |
| Resource Development | ✅ supply-chain 规则拦截恶意安装源 |
| Initial Access | ✅ reverse-shell + encoding-bypass 规则 |
| ML Model Access | ❌ 不适用（本项目不保护模型权重） |
| Execution | ✅ firewall.sh 全类别覆盖 |
| Persistence | ⚠️ file-guard 拦截敏感路径写入 |
| Defense Evasion | ✅ encoding-bypass 规则覆盖 8 种 CVE-2025-66032 绕过 |
| Collection | ✅ credential-exfil 规则拦截凭证窃取 |
| Exfiltration | ✅ network-attack 规则拦截 DNS/ICMP 外传 |
| Impact | ✅ destructive 规则拦截破坏性操作 |

---

## 明确不覆盖的范围

| 威胁 | 原因 |
|------|------|
| OS 内核级攻击 | 需沙箱/虚拟机隔离（本项目是应用层防火墙） |
| 网络层 DDoS | 需网络策略/网关 |
| 物理访问 | 超出软件范围 |
| 社会工程 | 超出技术范围 |
| MCP 服务器劫持 | 需 MCP allowlist + 签名校验（可考虑后续版本） |

---

## 安全假设

1. 用户已安装 jq（install.sh 预检）
2. ~/.claude/hooks/.checksums 未被同时篡改（攻击者需要同时修改 Hook 文件和校验和文件）
3. 用户定期拉取本项目更新以获取新规则和对抗样本
4. 攻击者未获得文件系统 root 权限（否则可禁用 Hook）
