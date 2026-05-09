---
name: secrets-leak
description: Deep secrets and credentials scan. Finds hardcoded API keys, tokens, private keys, certificates, and connection strings.
model: auto
context: fork
allowed-tools: Read, Grep, Glob
---

# Secrets Leak Scan

Deep scan for secrets, credentials, and sensitive data in code. Complements `content-guard.sh` (real-time write blocking) with a thorough static analysis approach.

## Scan Targets

### API Keys & Tokens
- OpenAI / Anthropic API keys (`sk-...`, `sk-ant-...`)
- AWS Access Keys (`AKIA...`)
- GitHub Tokens (`ghp_...`, `github_pat_...`)
- Slack Tokens (`xoxb-...`, `xoxp-...`)
- Stripe Keys (`sk_live_...`, `pk_live_...`)
- JWT tokens (header.payload.signature pattern)

### Private Keys & Certificates
- PEM private keys (`-----BEGIN RSA PRIVATE KEY-----`, etc.)
- SSH private keys (`id_rsa`, `id_ed25519`, `id_ecdsa`)
- PGP private keys
- Certificate private keys (`.pem`, `.key`, `.pfx`, `.p12`, `.jks`)

### Connection Strings
- Database URLs with embedded credentials (`mongodb://user:pass@host`)
- Redis URLs with passwords (`redis://:password@host`)
- Cloud service connection strings

### Configuration Files
- `.env` files that should be `.env.example`
- `credentials.json`, `secrets.yaml` in source control
- `.npmrc` with `_authToken`
- `.pypirc` with passwords
- `.git-credentials`, `.netrc`

### Logs & Output
- Sensitive data in `console.log` / `print` statements
- Error messages that leak internal paths or credentials
- Debug output that includes request bodies with tokens

## Scan Approach

1. Grep for known patterns (regex-based, same as content-guard)
2. Check git history for secrets that were committed then deleted (not just current state)
3. Check for `.env` files in git tracking (`git ls-files | grep '\.env'`)
4. Entropy-based detection for high-entropy strings >30 chars (heuristic, reports as "suspicious")

## Output Format

| Severity | Category | File:Line | Finding | Action |
|----------|----------|-----------|---------|--------|
| 🔴 Critical | API Key | .env:3 | OpenAI API key in plaintext | Rotate immediately, move to env var |
| 🟡 Warning | Suspicious | config.ts:42 | High-entropy string, possible token | Verify, rotate if confirmed |

End with risk summary: CRITICAL / HIGH / MEDIUM / LOW.

> If secrets are found in git history, recommend `git filter-branch` or `BFG Repo-Cleaner` and immediate key rotation.
