#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQL_FILE="$ROOT_DIR/scripts/fixtures/workspace_rls_probe.sql"
DEFAULT_DB_CONTAINER="supabase_db_$(basename "$ROOT_DIR")"
DB_CONTAINER="${SUPABASE_DB_CONTAINER:-$DEFAULT_DB_CONTAINER}"

if [[ ! -f "$SQL_FILE" ]]; then
  echo "workspace RLS probe SQL not found: $SQL_FILE" >&2
  exit 1
fi

if [[ -z "${PROBE_USER_ID:-}" ]]; then
  echo "PROBE_USER_ID is required" >&2
  exit 1
fi

if [[ -z "${PROBE_WORKSPACE_ID:-}" ]]; then
  echo "PROBE_WORKSPACE_ID is required" >&2
  exit 1
fi

if command -v psql >/dev/null 2>&1; then
  if [[ -z "${DATABASE_URL:-}" ]]; then
    echo "DATABASE_URL is required when using host psql" >&2
    exit 1
  fi
  PSQL_CMD=(psql "$DATABASE_URL")
  USE_STDIN_SQL=0
elif command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -Fxq "$DB_CONTAINER"; then
  PSQL_CMD=(docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres)
  USE_STDIN_SQL=1
else
  cat >&2 <<EOF
workspace RLS probe requires either:
  1. host 'psql' with DATABASE_URL set, or
  2. a running local Supabase DB container (default: $DB_CONTAINER)
EOF
  exit 1
fi

HAS_SCHEMA="$("${PSQL_CMD[@]}" -tA -c "select case when to_regclass('public.app_workspace') is null then '0' else '1' end")"
if [[ "$HAS_SCHEMA" != "1" ]]; then
  cat >&2 <<'EOF'
workspace tables are missing in the target database.
Run the probe against a migrated staging database, or initialize the local Supabase schema first.
EOF
  exit 1
fi

if [[ "$USE_STDIN_SQL" == "1" ]]; then
  "${PSQL_CMD[@]}" \
    -v ON_ERROR_STOP=1 \
    -v probe_user_id="$PROBE_USER_ID" \
    -v probe_workspace_id="$PROBE_WORKSPACE_ID" \
    -f - < "$SQL_FILE"
else
  "${PSQL_CMD[@]}" \
    -v ON_ERROR_STOP=1 \
    -v probe_user_id="$PROBE_USER_ID" \
    -v probe_workspace_id="$PROBE_WORKSPACE_ID" \
    -f "$SQL_FILE"
fi
