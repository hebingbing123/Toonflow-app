#!/usr/bin/env bash
# Create or refresh local dev admin (admin@openflow.local / admin123) via Supabase Auth admin API.
# Use when supabase is already running and you do not want `supabase db reset`.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v supabase >/dev/null 2>&1; then
  echo "supabase CLI not found" >&2
  exit 1
fi

eval "$(supabase status -o env 2>/dev/null | sed -n 's/^\([A-Z_]*\)=\(.*\)$/\1=\2/p')"

if [[ -z "${SERVICE_ROLE_KEY:-}" ]]; then
  echo "Supabase is not running. Start with: supabase start" >&2
  exit 1
fi

API_URL="${API_URL:-http://127.0.0.1:64321}"
EMAIL="${OPENFLOW_DEV_ADMIN_EMAIL:-admin@openflow.local}"
PASSWORD="${OPENFLOW_DEV_ADMIN_PASSWORD:-admin123}"

payload=$(printf '{"email":"%s","password":"%s","email_confirm":true}' "$EMAIL" "$PASSWORD")

response=$(curl -sS -w '\n%{http_code}' -X POST "$API_URL/auth/v1/admin/users" \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d "$payload")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
  echo "Created dev admin: $EMAIL"
  exit 0
fi

if echo "$body" | grep -qi 'already been registered'; then
  echo "Dev admin already exists: $EMAIL (sign in with password $PASSWORD)"
  exit 0
fi

echo "Failed to seed dev admin (HTTP $http_code): $body" >&2
exit 1
