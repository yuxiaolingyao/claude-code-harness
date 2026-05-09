#!/usr/bin/env bash
set -euo pipefail

cmd=$(jq -r '.tool_input.command // ""' 2>/dev/null || true)

# jq 不可用时放弃解析，直接放行（fail-open）
if [ -z "$cmd" ]; then
  exit 0
fi

dangerous_patterns=(
  'rm\s+(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r)\s+/'
  'rm\s+(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r)\s+~'
  'rm\s+(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r)\s+\$HOME'
  'git\s+push\s+.*(--force|-f)\s+.*(main|master)'
  'git\s+reset\s+--hard'
  '>\s*/dev/sda'
  'mkfs\.'
  'dd\s+if=.*of=/dev/'
  'chmod\s+777\s+/'
  'curl.*\|.*sh'
  'wget.*-O.*\|.*sh'
)

for pattern in "${dangerous_patterns[@]}"; do
  if echo "$cmd" | grep -Eiq "$pattern"; then
    echo "SECURITY BLOCK: command matches dangerous pattern '$pattern'" >&2
    echo "Blocked command: $cmd" >&2
    exit 2
  fi
done

exit 0
