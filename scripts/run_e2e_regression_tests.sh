#!/usr/bin/env bash
# Run backend pg_contract end-to-end regression tests against local Supabase/Postgres.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/local_test_env.sh"

TEST_FILTER="${1:-app::pg_contract_tests::e2e_regression_suite}"

load_local_env_file
if ! ensure_database_url; then
  echo "The E2E regression tests need DATABASE_URL." >&2
  echo "This script will also try 'supabase status -o env' automatically when available." >&2
  echo "Example:" >&2
  echo "  yarn supabase:start:db" >&2
  echo "  supabase db reset" >&2
  exit 1
fi

if [[ -z "${SUPABASE_JWT_SECRET:-}" ]]; then
  echo "The E2E regression tests also need SUPABASE_JWT_SECRET." >&2
  echo "Tip: source env/.env.dev or copy the JWT secret from 'supabase status' when running a full local stack." >&2
  exit 1
fi

echo "Resolved DATABASE_URL from ${DATABASE_URL_SOURCE}."
echo "Running E2E regression tests with filter: ${TEST_FILTER}"

cd "$ROOT/backend"
exec cargo test --package toonflow-server --lib "$TEST_FILTER" -- --ignored --nocapture
