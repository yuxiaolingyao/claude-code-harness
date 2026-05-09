---
name: code-review
description: Universal code review for any language. Checks null safety, exception handling, resource leaks, concurrency, and security.
model: auto
context: fork
allowed-tools: Read, Grep, Glob
---

# Code Review

Systematic code review for correctness, safety, and maintainability. Language-agnostic.

## Review Checklist

### Correctness
- Are edge cases handled? (null/None, empty collections, zero values)
- Are boundary conditions correct? (off-by-one, overflow)
- Is the logic consistent with surrounding code patterns?

### Safety
- Are exceptions handled properly? (no empty catch blocks)
- Are resources closed/cleaned up? (connections, files, streams)
- Are there potential null pointer / undefined access issues?
- Is user input validated and sanitized?

### Performance
- Are there unnecessary allocations or copies?
- Are loops efficient? (no repeated work, pre-size collections)
- Are database queries missing indexes or causing N+1?

### Security
- Any hardcoded secrets, tokens, or passwords?
- Any SQL/command injection vectors?
- Any path traversal or file access issues?
- Is sensitive data logged or exposed?

### Maintainability
- Are names clear and descriptive?
- Is the change minimal (no unrelated refactoring)?
- Are tests adequate for the changed paths?

## Output Format

| Severity | Category | File:Line | Issue | Fix |
|----------|----------|-----------|-------|-----|
| 🔴 Critical | Security | ... | ... | ... |
| 🟡 Warning | Performance | ... | ... | ... |
| 🔵 Note | Style | ... | ... | ... |

Report findings, then recommend: APPROVE / CHANGES_REQUESTED / COMMENT.
