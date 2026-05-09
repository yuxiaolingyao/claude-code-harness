# 致谢与参考

本项目在设计和实现中参考了以下开源项目的工作。

## 核心参考

| 项目 | 借鉴内容 |
|------|---------|
| [OACB](https://github.com/websentry-ai/oacb) (Apache 2.0) | 对抗测试方法论、fail-closed Hook 设计、OWASP ASI 威胁模型映射思路 |
| [@rezzed.ai/guardian](https://www.npmjs.com/package/@rezzed.ai/guardian) (MIT) | 50+ 危险命令模式库、审计日志 JSONL 格式、enforce/audit 模式切换 |
| [CC Cortex](https://pypi.org/project/cc-cortex/) | 哨兵反循环检测概念（暴力重试/编辑循环/分析瘫痪） |
| [Claude Code Hooks 文档](https://code.claude.com/docs/en/hooks) | hookSpecificOutput JSON 决策格式 |

## 一般参考

以下项目在设计讨论中提供了有价值的参考，但未直接借鉴代码或具体实现：

- [Captain Hook](https://www.securityreview.ai/blog/captain-hook-ai-agent-policy-enforcement-for-claude) — YAML 策略引擎概念
- [nyolo](https://www.npmjs.com/package/nyolo) — ESLint 风格 flat config 思路
- [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice) — CLAUDE.md 最佳实践
- [Matt Pocock's Claude Code Skills](https://github.com/mattpocock) — Skill 设计参考
- [Redpanda ui-harness](https://github.com/redpanda-data/ui-harness) — 团队共享 harness 概念
- [arthus-harness](https://www.npmjs.com/package/create-arthus-harness) — npx 一键安装思路

## 安全标准参考

- OWASP Top 10 for Agentic Applications 2026 (ASI01-ASI10)
- MITRE ATLAS v5.4.0
- CVE-2025-66032, CVE-2025-54794/5, CVE-2025-55284, CVE-2025-59536, CVE-2026-21852

---

本项目同样以 MIT 协议开源。感谢所有为 AI 编码安全做出贡献的社区。
