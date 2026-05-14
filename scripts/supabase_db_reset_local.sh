#!/usr/bin/env bash
# Local `supabase db reset` with Colima-friendly recovery.
#
# Symptom: migrations + seed finish, then CLI exits 1 with
#   `supabase_storage_* container is not ready: starting|unhealthy`
# Storage logs may show `ECONNREFUSED` to Postgres during the post-reset restart race.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOG="$(mktemp -t toonflow_db_reset.XXXXXX)"
trap 'rm -f "$LOG"' EXIT

set +e
supabase db reset --yes "$@" 2>&1 | tee "$LOG"
RESET_RC=${PIPESTATUS[0]}
set -e

if [[ "$RESET_RC" -eq 0 ]]; then
  echo "supabase db reset: OK"
  exit 0
fi

if grep -q 'Applying migration 20260522100000_app_user_search_saved_view.sql' "$LOG"; then
  echo >&2 ""
  echo >&2 "supabase db reset: migrations reached saved_views; CLI failed during container restart (often storage health on Colima)."
else
  echo >&2 ""
  echo >&2 "supabase db reset failed before final migrations — see log above."
  exit "$RESET_RC"
fi

echo >&2 "Recovering: supabase start --ignore-health-check"
echo >&2 "If you only need Postgres for DB-backed tests afterward, prefer: yarn supabase:start:db"
supabase start --ignore-health-check --yes

STORAGE_CTN="supabase_storage_$(basename "$ROOT")"
if command -v docker >/dev/null 2>&1 && docker ps -a --format '{{.Names}}' | grep -qx "$STORAGE_CTN"; then
  echo >&2 "Restarting $STORAGE_CTN and waiting for healthy (up to 120s)..."
  docker restart "$STORAGE_CTN" >/dev/null 2>&1 || true
  for _ in $(seq 1 24); do
    STATUS="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$STORAGE_CTN" 2>/dev/null || echo unknown)"
    if [[ "$STATUS" == "healthy" ]]; then
      echo >&2 "Storage container healthy."
      break
    fi
    sleep 5
  done
fi

if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "supabase_db_$(basename "$ROOT")"; then
  if docker exec "supabase_db_$(basename "$ROOT")" psql -U postgres -d postgres -tAc \
    "SELECT to_regclass('public.app_user_search_saved_view');" 2>/dev/null | grep -q app_user_search_saved_view; then
    echo >&2 "Postgres schema OK (app_user_search_saved_view present)."
    supabase status
    exit 0
  fi
fi

echo >&2 "Recovery incomplete: Postgres or schema check failed."
exit "$RESET_RC"
