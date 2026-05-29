#!/usr/bin/env bash
# Ops health snapshot for local/staging (28) — read-only curl probes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_BASE="${STUDIO_API_BASE_URL:-http://127.0.0.1:8666}"

probe() {
  local path="$1"
  local url="${API_BASE}${path}"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 "$url" || echo "000")
  if [[ "$code" =~ ^2 ]]; then
    echo "OK   $path ($code)"
  else
    echo "FAIL $path ($code)"
    return 1
  fi
}

echo "== studio_ops_health_check @ $API_BASE =="
fail=0
probe /health || fail=1
probe /ready || fail=1
probe /version || fail=1
if [[ "$fail" -eq 0 ]]; then
  echo "All probes passed."
else
  echo "One or more probes failed."
  exit 1
fi
