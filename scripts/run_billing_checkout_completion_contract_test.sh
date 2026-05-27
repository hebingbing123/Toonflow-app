#!/usr/bin/env bash
# PG contract: checkout ingest_webhook before mark_paid + paid-session reconcile.
# Usage (repo root): ./scripts/run_billing_checkout_completion_contract_test.sh
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
for filter in \
  checkout_complete_upgrades \
  checkout_paid_session_reconciles \
  checkout_pending_session_upgrades
do
  echo "=== cargo test ${filter} (ignored) ==="
  cargo test "${filter}" --lib -- --ignored --nocapture --test-threads=1 "$@"
done
