#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQL_FILE="$ROOT_DIR/scripts/fixtures/workspace_rls_probe.sql"

if [[ ! -f "$SQL_FILE" ]]; then
  echo "workspace RLS probe SQL not found: $SQL_FILE" >&2
  exit 1
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required" >&2
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

psql "$DATABASE_URL" \
  -v ON_ERROR_STOP=1 \
  -v probe_user_id="$PROBE_USER_ID" \
  -v probe_workspace_id="$PROBE_WORKSPACE_ID" \
  -f "$SQL_FILE"
