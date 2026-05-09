---
name: security-check
description: Security review for hardcoded secrets, injection, path traversal, and unsafe patterns. Language-agnostic.
model: auto
context: fork
allowed-tools: Read, Grep, Glob
---

# Security Check

Scan code changes for security vulnerabilities. Language-agnostic, pattern-based.

## Scan Targets

### Secrets & Credentials
- Hardcoded passwords, API keys, tokens
- Private keys (PEM, SSH, PGP)
- Connection strings with credentials
- OAuth client secrets

### Injection
- SQL query concatenation (not parameterized)
- OS command injection (user input in shell commands)
- XSS: unescaped user input in HTML/JS output
- Path traversal: user input in file paths
- Log injection: user input in log messages

### Access Control
- Missing authorization checks on endpoints
- Direct object references without ownership validation
- Privilege escalation paths

### Cryptography
- Hardcoded salts or IVs
- Weak algorithms (MD5, SHA1, DES, RC4)
- Custom crypto implementations

### Data Exposure
- Sensitive data in logs or error messages
- Debug endpoints in production code
- Stack traces returned to clients

## Output Format

| Severity | Category | File:Line | Finding | Remediation |
|----------|----------|-----------|---------|-------------|
| Critical | ... | ... | ... | ... |

End with a risk summary: CRITICAL / HIGH / MEDIUM / LOW.
