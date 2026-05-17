#!/usr/bin/env bash
# Run PG contract test `publish_quality_gate_job_contract`.
# Usage (repo root): ./scripts/run_publish_quality_gate_job_contract_test.sh
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
  echo "Need DATABASE_URL and SUPABASE_JWT_SECRET (e.g. source env/.env.dev)." >&2
  exit 1
fi

echo "Using DATABASE_URL host/port: $(echo "$DATABASE_URL" | sed 's/.*@\([^/]*\).*/\1/')"
cd backend
exec cargo test publish_quality_gate_job_contract -- --ignored --nocapture "$@"
