#!/usr/bin/env bash
# Run backend/tests/search_api_test.rs in either default or database-backed mode.
# Usage:
#   ./scripts/run_search_api_tests.sh
#   ./scripts/run_search_api_tests.sh --db
#   ./scripts/run_search_api_tests.sh --db test_search_pagination
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run_search_api_tests.sh [test_name]
  ./scripts/run_search_api_tests.sh --db [test_name]

Modes:
  (default)  Run the lightweight default path for backend/tests/search_api_test.rs
  --db       Run ignored database-backed search tests with --ignored --nocapture

Environment:
  - If env/.env.dev exists, this script will source it automatically.
  - In --db mode, the script prefers DATABASE_URL, then falls back to
    `supabase status -o env` and reuses local DB_URL when available.

Examples:
  ./scripts/run_search_api_tests.sh
  ./scripts/run_search_api_tests.sh --db
  ./scripts/run_search_api_tests.sh --db test_search_pagination
EOF
}

load_database_url_from_supabase_status() {
  if ! command -v supabase >/dev/null 2>&1; then
    return 1
  fi

  local status_output
  if ! status_output="$(supabase status -o env 2>/dev/null)"; then
    return 1
  fi

  local db_url
  db_url="$(printf '%s\n' "$status_output" | sed -n 's/^DB_URL="\([^"]*\)"$/\1/p' | head -n 1)"
  if [[ -z "$db_url" ]]; then
    return 1
  fi

  export DATABASE_URL="$db_url"
  DATABASE_URL_SOURCE="supabase status -o env"
  return 0
}

db_host_port() {
  python3 - <<'PY'
from urllib.parse import urlparse
import os

url = os.environ.get("DATABASE_URL", "")
parsed = urlparse(url)
host = parsed.hostname or ""
port = parsed.port or 5432
print(f"{host} {port}")
PY
}

db_tcp_reachable() {
  python3 - <<'PY'
from urllib.parse import urlparse
import os
import socket
import sys

url = os.environ.get("DATABASE_URL", "")
parsed = urlparse(url)
host = parsed.hostname
port = parsed.port or 5432

if not host:
    sys.exit(2)

sock = socket.socket()
sock.settimeout(2)
try:
    sock.connect((host, port))
except OSError:
    sys.exit(1)
finally:
    sock.close()
PY
}

DB_MODE=false
TEST_NAME=""

for arg in "$@"; do
  case "$arg" in
    --db)
      DB_MODE=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      if [[ -n "$TEST_NAME" ]]; then
        echo "Only one optional test name is supported: got '$TEST_NAME' and '$arg'." >&2
        usage >&2
        exit 1
      fi
      TEST_NAME="$arg"
      ;;
  esac
done

if [[ -f env/.env.dev ]]; then
  set -a
  # shellcheck disable=SC1091
  source env/.env.dev
  set +a
fi

cd backend

if [[ "$DB_MODE" == true ]]; then
  if [[ -z "${DATABASE_URL:-}" ]]; then
    load_database_url_from_supabase_status || true
  fi

  if [[ -z "${DATABASE_URL:-}" ]]; then
    echo "Search API DB test mode needs DATABASE_URL for sqlx::test setup." >&2
    echo "Tip: start local Supabase and export DATABASE_URL, or source env/.env.dev first." >&2
    echo "This script will also try 'supabase status -o env' automatically when available." >&2
    echo "Example:" >&2
    echo "  yarn supabase:start:db" >&2
    echo "  # or: supabase start" >&2
    echo "  supabase db reset" >&2
    echo "  export DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres" >&2
    exit 1
  fi

  if [[ -z "${DATABASE_URL_SOURCE:-}" ]]; then
    if [[ -f "$ROOT/env/.env.dev" ]]; then
      DATABASE_URL_SOURCE="env/.env.dev or current shell"
    else
      DATABASE_URL_SOURCE="current shell"
    fi
  fi

  read -r DB_HOST DB_PORT <<< "$(db_host_port)"
  if ! db_tcp_reachable; then
    echo "Search API DB test mode found DATABASE_URL but could not reach ${DB_HOST}:${DB_PORT}." >&2
    echo "Tip: start local Supabase/Postgres first, then retry." >&2
    echo "Examples:" >&2
    echo "  yarn supabase:start:db" >&2
    echo "  # or: supabase start" >&2
    echo "  supabase status" >&2
    echo "  supabase db reset" >&2
    exit 1
  fi

  echo "Resolved DATABASE_URL from ${DATABASE_URL_SOURCE}."
  echo "Running database-backed search API tests against ${DB_HOST}:${DB_PORT}"
  LOG_FILE="$(mktemp "${TMPDIR:-/tmp}/toonflow-search-api-tests.XXXXXX")"
  trap 'rm -f "$LOG_FILE"' EXIT

  set +e
  if [[ -n "$TEST_NAME" ]]; then
    cargo test --test search_api_test "$TEST_NAME" -- --ignored --nocapture 2>&1 | tee "$LOG_FILE"
  else
    cargo test --test search_api_test -- --ignored --nocapture 2>&1 | tee "$LOG_FILE"
  fi
  TEST_RC=${PIPESTATUS[0]}
  set -e

  if [[ "$TEST_RC" -ne 0 ]] && grep -q 'failed to connect to setup test database: PoolTimedOut' "$LOG_FILE"; then
    echo >&2 ""
    echo >&2 "Search API DB tests reached sqlx::test setup but the setup database pool timed out." 
    echo >&2 "This usually means DATABASE_URL is present, but the Postgres test environment is still not usable for sqlx::test fan-out."
    echo >&2 "Typical next checks:"
    echo >&2 "  1. Ensure local Supabase/Postgres is fully healthy."
    echo >&2 "     For DB-only recovery, prefer: yarn supabase:start:db"
    echo >&2 "  2. Run 'supabase db reset' so the schema/extensions are current."
    echo >&2 "  3. Retry a single test first: ./scripts/run_search_api_tests.sh --db test_search_pagination"
  fi

  exit "$TEST_RC"
fi

if [[ -n "$TEST_NAME" ]]; then
  exec cargo test --test search_api_test "$TEST_NAME"
fi
exec cargo test --test search_api_test
