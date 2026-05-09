#!/usr/bin/env bash
set -euo pipefail

file_path=$(jq -r '.tool_input.file_path // ""' 2>/dev/null || true)

# jq 不可用时放弃解析，直接放行（fail-open）
if [ -z "$file_path" ]; then
  exit 0
fi

sensitive_patterns=(
  '\.env$'
  '\.env\.'
  'credentials'
  'secret'
  '\.pem$'
  '\.key$'
  'CRITICAL_RULES\.md$'
)

for pattern in "${sensitive_patterns[@]}"; do
  if echo "$file_path" | grep -Eiq "$pattern"; then
    echo "SECURITY BLOCK: file matches sensitive pattern '$pattern'" >&2
    echo "Blocked file: $file_path" >&2
    echo "To modify this file, edit it manually or grant explicit authorization." >&2
    exit 2
  fi
done

exit 0
