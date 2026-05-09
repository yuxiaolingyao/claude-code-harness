#!/usr/bin/env bash
# Integrity check — SessionStart
# Verifies SHA256 checksums of all hooks, rules, and core files.
# Blocks session startup if any file has been tampered with.
set -euo pipefail

CHECKSUM_FILE="$HOME/.claude/hooks/.checksums"

if [ ! -f "$CHECKSUM_FILE" ]; then
  echo "[integrity] No checksum file found — skipping" >&2
  exit 0
fi

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "[integrity] sha256sum not available — skipping" >&2
  exit 0
fi

result=$(sha256sum -c "$CHECKSUM_FILE" --quiet 2>&1) || true
# sha256sum returns non-zero on mismatch, stderr has the details

if [ -n "$result" ]; then
  echo "=========================================" >&2
  echo "INTEGRITY ALERT: hook/rule files modified!" >&2
  echo "$result" >&2
  echo "=========================================" >&2
  echo "This may indicate unauthorized tampering." >&2
  echo "Re-run: cd ~/claude-code-harness && bash install.sh" >&2
  exit 2
fi

exit 0
