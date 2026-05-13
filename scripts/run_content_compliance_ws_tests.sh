#!/usr/bin/env bash
# Run PG contract tests for content compliance WebSocket push notifications.
# Usage (repo root): ./scripts/run_content_compliance_ws_tests.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f env/.env.dev ]]; then
  set -a
  # shellcheck disable=SC1091
  source env/.env.dev
  set +a
fi

if [[ -z "${DATABASE_URL:-}" ]] || [[ -z "${SUPABASE_JWT_SECRET:-}" ]]; then
  echo "Need DATABASE_URL and SUPABASE_JWT_SECRET (e.g. source env/.env.dev or export manually)." >&2
  exit 1
fi

echo "Using DATABASE_URL host/port: $(echo "$DATABASE_URL" | sed 's/.*@\([^/]*\).*/\1/')"
cd backend

# Run all content compliance WS push tests
echo "Running content compliance WebSocket push tests..."
exec cargo test content_compliance_ws -- --ignored --nocapture "$@"
