# Claude Code Harness — 项目自身规约

> Dogfooding: 本项目使用自身定义的 Harness 规则。

## 技术栈
- 纯文本配置（Markdown + JSON + Bash），无编译依赖
- 目标平台：Linux / macOS / Windows Git Bash

## 规则

### 安全
- CRITICAL_RULES.md 保持 30 行以内（每次注入消耗 token）
- Hook 脚本 fail-closed：jq 不可用或规则文件丢失时 exit 2（拒绝操作）
- Hook 脚本禁止 `cat` 回退解析 stdin

### 可移植性
- 正则规则与执行脚本分离：模式存 rules/*.json，Hook 脚本只做通用匹配引擎
- 所有 Shell 脚本使用 LF 换行
- jq 是硬依赖（install.sh 预检 + 安装指引），无 jq 时 Hook 拒绝所有操作（fail-closed）

### 版本
- 语义化版本：`MAJOR.MINOR.PATCH`
- MAJOR：破坏性 hook 规则变更
- MINOR：新增 skill 或规则
- PATCH：修复、文档
