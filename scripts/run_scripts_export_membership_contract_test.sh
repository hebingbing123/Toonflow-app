#!/usr/bin/env bash
# PG contract: script export zip respects workspace membership (EXISTS filter).
# Usage (repo root): ./scripts/run_scripts_export_membership_contract_test.sh
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
  echo "Need DATABASE_URL and SUPABASE_JWT_SECRET (e.g. source env/.env.dev or backend/.env)." >&2
  exit 1
fi

echo "Using DATABASE_URL host/port: $(echo "$DATABASE_URL" | sed 's/.*@\([^/]*\).*/\1/')"
cd backend
exec cargo test scripts_export_membership --lib -- --ignored --nocapture --test-threads=1 "$@"
