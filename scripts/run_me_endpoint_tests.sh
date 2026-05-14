#!/usr/bin/env bash
# Run backend/tests/me_endpoint_test.rs against a local Postgres database.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/local_test_env.sh"

TEST_NAME="${1:-}"

load_local_env_file
if ! ensure_test_database_url; then
  echo "The /me integration tests need TEST_DATABASE_URL or DATABASE_URL." >&2
  echo "This script will also try 'supabase status -o env' automatically when available." >&2
  echo "Example:" >&2
  echo "  yarn supabase:start:db" >&2
  echo "  supabase db reset" >&2
  exit 1
fi

echo "Resolved TEST_DATABASE_URL from ${TEST_DATABASE_URL_SOURCE}."

cd "$ROOT/backend"
if [[ -n "$TEST_NAME" ]]; then
  exec cargo test --test me_endpoint_test "$TEST_NAME"
fi
exec cargo test --test me_endpoint_test
