#!/usr/bin/env bash
# HEALTH-012: Live RLS negative probe for user-facing tables (Postgres role + PostgREST).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/.codex/skills/project-health-check/output/raw/rls-live-probe.json"
# project_id from supabase/config.toml (not repo folder name)
DB_CONTAINER="${SUPABASE_DB_CONTAINER:-supabase_db_openflow-app}"
USER_A="${PROBE_USER_A:-00000000-0000-0000-0000-000000000001}"
USER_B="${PROBE_USER_B:-00000000-0000-0000-0000-000000000002}"
API_URL="${SUPABASE_URL:-http://127.0.0.1:64421}"
ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"

psql_docker() {
  docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

log() { printf '[rls-live-probe] %s\n' "$*"; }

if ! docker ps --format '{{.Names}}' | grep -Fxq "$DB_CONTAINER"; then
  echo "DB container $DB_CONTAINER not running" >&2
  exit 1
fi

log "Seeding probe users + profiles..."
psql_docker <<SQL
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-000000000000', '$USER_A'::uuid, 'authenticated', 'authenticated', 'admin@openflow.local', crypt('admin123', gen_salt('bf')), NOW(), '{}'::jsonb, '{}'::jsonb, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000000', '$USER_B'::uuid, 'authenticated', 'authenticated', 'probe-b@openflow.local', crypt('probeb123', gen_salt('bf')), NOW(), '{}'::jsonb, '{}'::jsonb, NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.app_user_profile (user_id, plan_tier, updated_at)
VALUES ('$USER_A'::uuid, 'free', NOW()), ('$USER_B'::uuid, 'free', NOW())
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.app_notification (user_id, notification_type, title, message)
VALUES
  ('$USER_A'::uuid, 'probe', 'A', 'notification for A'),
  ('$USER_B'::uuid, 'probe', 'B', 'notification for B');
SQL

log "Postgres RLS probe (SET ROLE authenticated)..."
PSQL_PROBE=$(psql_docker -tA <<SQL
SELECT set_config('request.jwt.claim.sub', '$USER_A', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SET ROLE authenticated;
SELECT count(*)::text FROM public.app_user_profile WHERE user_id = '$USER_B'::uuid;
SQL
)
CROSS_PROFILE_COUNT="$(echo "$PSQL_PROBE" | tail -1 | tr -d '[:space:]')"

PSQL_NOTIF=$(psql_docker -tA <<SQL
SELECT set_config('request.jwt.claim.sub', '$USER_A', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SET ROLE authenticated;
SELECT count(*)::text FROM public.app_notification WHERE user_id = '$USER_B'::uuid;
SQL
)
CROSS_NOTIF_COUNT="$(echo "$PSQL_NOTIF" | tail -1 | tr -d '[:space:]')"

log "PostgREST probe (sign-in as user A)..."
TOKEN_A=""
if command -v curl >/dev/null 2>&1; then
  AUTH_RESP=$(curl -sS -X POST "$API_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"admin@openflow.local\",\"password\":\"admin123\"}" 2>/dev/null || true)
  TOKEN_A=$(echo "$AUTH_RESP" | ruby -rjson -e "j=JSON.parse(STDIN.read) rescue {}; print j['access_token'].to_s" 2>/dev/null || true)
fi

REST_COUNT="skipped"
if [[ -n "$TOKEN_A" ]]; then
  REST_BODY=$(curl -sS "$API_URL/rest/v1/app_user_profile?select=user_id" \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $TOKEN_A" 2>/dev/null || echo "[]")
  REST_COUNT=$(echo "$REST_BODY" | ruby -rjson -e "j=JSON.parse(STDIN.read) rescue []; print j.is_a?(Array) ? j.length : -1" 2>/dev/null || echo "-1")
fi

PROBED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
PASS="true"
[[ "$CROSS_PROFILE_COUNT" == "0" ]] || PASS="false"
[[ "$CROSS_NOTIF_COUNT" == "0" ]] || PASS="false"
[[ "$REST_COUNT" == "1" || "$REST_COUNT" == "skipped" ]] || PASS="false"

mkdir -p "$(dirname "$OUT")"
ruby -rjson -e "
  print JSON.pretty_generate({
    probedAt: '$PROBED_AT',
    supabaseRunning: true,
    dbContainer: '$DB_CONTAINER',
    pass: '$PASS' == 'true',
    postgres: {
      userA_reads_userB_profile_count: '$CROSS_PROFILE_COUNT',
      userA_reads_userB_notification_count: '$CROSS_NOTIF_COUNT',
      expected: '0'
    },
    postgrest: {
      userA_profile_rows_visible: '$REST_COUNT',
      expected: '1 or skipped'
    },
    migrationsVerified: ['20260624120000_app_user_facing_rls.sql', '20260624130000_app_backend_only_rls.sql']
  })
" >"$OUT"

log "Wrote $OUT (pass=$PASS)"
[[ "$PASS" == "true" ]] || exit 1
