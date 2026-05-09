# Claude Code Harness — 项目自身规约

> Dogfooding: 本项目使用自身定义的 Harness 规则。

## 技术栈
- 纯文本配置（Markdown + JSON + Bash），无编译依赖
- 目标平台：Linux / macOS / Windows Git Bash

## 规则

### 安全
- CRITICAL_RULES.md 保持 30 行以内（每次注入消耗 token）
- Hook 脚本必须包含 jq 不可用时的 fail-open 回退（`if [ -z "$var" ]; then exit 0; fi`）
- Hook 脚本禁止 `cat` 回退解析 stdin

### 可移植性
- Hook 脚本的 regex 模式禁止出现在脚本自身的字符串字面量中（避免自匹配）
- 所有 Shell 脚本使用 LF 换行
- 不依赖 jq（降级提示手动合并）

### 版本
- 语义化版本：`MAJOR.MINOR.PATCH`
- MAJOR：破坏性 hook 规则变更
- MINOR：新增 skill 或规则
- PATCH：修复、文档
