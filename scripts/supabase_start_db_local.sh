#!/usr/bin/env bash
# Start only the local Supabase Postgres service needed by sqlx::test-backed suites.
#
# This avoids unrelated service conflicts (vector, analytics, studio, etc.) when the
# immediate goal is to make DATABASE_URL reachable for backend DB tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXCLUDES="gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor"

echo "Starting local Supabase database only..."
supabase start -x "$EXCLUDES" "$@"

echo
echo "Database status:"
supabase status
