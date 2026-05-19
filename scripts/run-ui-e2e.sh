#!/usr/bin/env bash
# Full-stack UI E2E: local Supabase + Rust backend + Flutter integration tests (macOS desktop).
#
# Usage:
#   bash scripts/run-ui-e2e.sh              # smoke test (default, faster)
#   bash scripts/run-ui-e2e.sh --gallery    # compact product-shell gallery (~7 PNGs)
#   bash scripts/run-ui-e2e.sh --full-gallery  # expanded gallery (30+ PNGs)
#   OPENFLOW_UI_E2E_SKIP_RESET=1 bash scripts/run-ui-e2e.sh
#
# Env:
#   OPENFLOW_UI_E2E_PORT          API port (default 8666)
#   OPENFLOW_UI_E2E_DEVICE        flutter -d target (default macos)
#   OPENFLOW_UI_E2E_SKIP_RESET    skip supabase db reset when starting stack
#   OPENFLOW_UI_E2E_SKIP_BACKEND  do not start/stop backend (already running)
#   OPENFLOW_UI_E2E_LOG_DIR       log directory (default mktemp under /tmp)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND="$ROOT/frontend"
# shellcheck disable=SC1091
source "$ROOT/scripts/local_test_env.sh"

TEST_MODE="smoke"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --gallery)
      TEST_MODE="gallery"
      shift
      ;;
    --full-gallery)
      TEST_MODE="full_gallery"
      shift
      ;;
    --smoke)
      TEST_MODE="smoke"
      shift
      ;;
    -h | --help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1 (try --smoke, --gallery, or --full-gallery)" >&2
      exit 2
      ;;
  esac
done

PORT="${OPENFLOW_UI_E2E_PORT:-8666}"
DEVICE="${OPENFLOW_UI_E2E_DEVICE:-macos}"
API_BASE="http://127.0.0.1:${PORT}"
LOG_DIR="${OPENFLOW_UI_E2E_LOG_DIR:-$(mktemp -d /tmp/openflow-ui-e2e.XXXXXX)}"
mkdir -p "$LOG_DIR"

BACKEND_PID=""
STARTED_SUPABASE=0
STARTED_BACKEND=0
OVERALL_RC=0
START_TS="$(date +%s)"

log() {
  printf '[ui-e2e] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Missing required command: $1"
    exit 127
  fi
}

supabase_is_running() {
  command -v supabase >/dev/null 2>&1 || return 1
  (cd "$ROOT" && supabase status >/dev/null 2>&1)
}

supabase_auth_ready() {
  (cd "$ROOT" && supabase status -o env 2>/dev/null) | grep -q '^SERVICE_ROLE_KEY=.'
}

ensure_supabase_ready() {
  if ! supabase_auth_ready; then
    log "Auth/Kong not up (common after db reset) — starting full Supabase stack..."
    (cd "$ROOT" && supabase start --ignore-health-check) 2>&1 | tee -a "$LOG_DIR/supabase-start.log"
  fi
  local attempts="${1:-60}"
  for _ in $(seq 1 "$attempts"); do
    if supabase_auth_ready; then
      log "Supabase API ready"
      return 0
    fi
    sleep 2
  done
  log "Supabase Auth/API did not become ready in time"
  (cd "$ROOT" && supabase status) >&2 || true
  return 1
}

wait_for_http() {
  local url="$1"
  local label="${2:-$url}"
  local attempts="${3:-90}"
  for _ in $(seq 1 "$attempts"); do
    if curl -sf "$url" >/dev/null 2>&1; then
      log "$label is up"
      return 0
    fi
    sleep 1
  done
  log "Timed out waiting for $label ($url)"
  return 1
}

cleanup() {
  local exit_code=$?
  if [[ "$STARTED_BACKEND" -eq 1 ]] && [[ -n "$BACKEND_PID" ]]; then
    log "Stopping backend (pid $BACKEND_PID)"
    kill "$BACKEND_PID" 2>/dev/null || true
    wait "$BACKEND_PID" 2>/dev/null || true
  fi
  if [[ "$STARTED_SUPABASE" -eq 1 ]] && [[ "${OPENFLOW_UI_E2E_STOP_SUPABASE:-}" == "1" ]]; then
    log "Stopping Supabase (OPENFLOW_UI_E2E_STOP_SUPABASE=1)"
    (cd "$ROOT" && supabase stop) >/dev/null 2>&1 || true
  fi
  if [[ $exit_code -ne 0 ]]; then
    OVERALL_RC=$exit_code
  fi
}
trap cleanup EXIT

require_cmd supabase
require_cmd curl
require_cmd flutter

if [[ "$(uname -s)" != "Darwin" ]]; then
  log "Host is not macOS — integration tests expect a desktop device; set OPENFLOW_UI_E2E_DEVICE if needed"
fi

flutter_has_device() {
  (cd "$FRONTEND" && flutter devices --machine 2>/dev/null) | grep -q "\"id\": \"${DEVICE}\""
}

if ! flutter_has_device; then
  log "No Flutter device with id '$DEVICE'. Run: cd frontend && flutter devices"
  exit 125
fi

load_local_env_file

if ! supabase_is_running; then
  log "Starting Supabase (full local stack for Auth)..."
  (cd "$ROOT" && supabase start --ignore-health-check) 2>&1 | tee "$LOG_DIR/supabase-start.log"
  STARTED_SUPABASE=1
else
  log "Supabase already running"
fi
ensure_supabase_ready || exit 1

eval "$(cd "$ROOT" && supabase status -o env 2>/dev/null | sed -n 's/^\([A-Z_]*\)=\(.*\)$/\1=\2/p')" || true

if [[ -n "${DB_URL:-}" ]]; then
  export DATABASE_URL="$DB_URL"
  DATABASE_URL_SOURCE="supabase status -o env"
elif ! load_database_url_from_supabase_status; then
  log "Could not resolve DATABASE_URL from supabase status"
  exit 1
fi

SUPABASE_URL="${API_URL:-${SUPABASE_URL:-}}"
SUPABASE_ANON_KEY="${ANON_KEY:-${SUPABASE_ANON_KEY:-}}"
if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  log "Missing API_URL/ANON_KEY from supabase status — Auth stack required for UI E2E"
  exit 1
fi
log "Supabase URL for Flutter: $SUPABASE_URL"

if [[ -z "${SUPABASE_JWT_SECRET:-}" ]]; then
  : # filled by eval above when present
fi
if [[ -z "${SUPABASE_JWT_SECRET:-}" ]]; then
  export SUPABASE_JWT_SECRET="super-secret-jwt-token-with-at-least-32-characters-long"
  log "Using default local SUPABASE_JWT_SECRET"
fi

if [[ "${OPENFLOW_UI_E2E_FORCE_CLEAN:-}" == "1" ]]; then
  log "OPENFLOW_UI_E2E_FORCE_CLEAN=1 — supabase stop --no-backup"
  (cd "$ROOT" && supabase stop --no-backup) 2>&1 | tee "$LOG_DIR/supabase-clean.log"
  STARTED_SUPABASE=1
fi

if [[ "${OPENFLOW_UI_E2E_SKIP_RESET:-}" != "1" ]]; then
  log "Applying migrations + seed (supabase db reset)..."
  set +e
  bash "$ROOT/scripts/supabase_db_reset_local.sh" 2>&1 | tee "$LOG_DIR/supabase-db-reset.log"
  RESET_RC=${PIPESTATUS[0]}
  set -e
  if [[ "$RESET_RC" -ne 0 ]]; then
    log "db reset exited $RESET_RC — waiting for DB healthy and retrying stack start..."
    for _ in $(seq 1 24); do
      DB_CTN="$(docker ps --format '{{.Names}}' 2>/dev/null | grep '^supabase_db_' | head -n1 || true)"
      if [[ -n "$DB_CTN" ]] && docker inspect -f '{{.State.Health.Status}}' "$DB_CTN" 2>/dev/null | grep -q healthy; then
        break
      fi
      sleep 5
    done
  fi
  ensure_supabase_ready || exit 1
else
  log "Skipping db reset (OPENFLOW_UI_E2E_SKIP_RESET=1)"
fi

fix_auth_seed_null_tokens() {
  local db_ctn
  db_ctn="$(docker ps --format '{{.Names}}' 2>/dev/null | grep '^supabase_db_' | head -n1 || true)"
  [[ -n "$db_ctn" ]] || return 0
  docker exec "$db_ctn" psql -U postgres -d postgres -qc "
    UPDATE auth.users SET
      confirmation_token = COALESCE(confirmation_token, ''),
      recovery_token = COALESCE(recovery_token, ''),
      email_change_token_new = COALESCE(email_change_token_new, ''),
      email_change = COALESCE(email_change, '')
    WHERE confirmation_token IS NULL OR recovery_token IS NULL
       OR email_change_token_new IS NULL OR email_change IS NULL;
  " >/dev/null 2>&1 || true
}

fix_auth_seed_null_tokens

log "Ensuring dev admin user..."
if ! bash "$ROOT/scripts/seed_local_dev_admin.sh" 2>&1 | tee "$LOG_DIR/seed-dev-admin.log"; then
  log "Retrying dev admin seed after brief wait..."
  sleep 5
  ensure_supabase_ready 30 || exit 1
  bash "$ROOT/scripts/seed_local_dev_admin.sh" 2>&1 | tee -a "$LOG_DIR/seed-dev-admin.log"
fi

export PORT="$PORT"
export API_BASE_URL="$API_BASE"

if [[ "${OPENFLOW_UI_E2E_SKIP_BACKEND:-}" != "1" ]]; then
  log "Building and starting Rust backend on $API_BASE ..."
  (
    cd "$ROOT/backend"
    cargo build --bin openflow-server
  ) 2>&1 | tee "$LOG_DIR/backend-build.log"
  (
    cd "$ROOT/backend"
    exec env PORT="$PORT" DATABASE_URL="$DATABASE_URL" SUPABASE_JWT_SECRET="$SUPABASE_JWT_SECRET" \
      cargo run --quiet --bin openflow-server
  ) >"$LOG_DIR/backend.log" 2>&1 &
  BACKEND_PID=$!
  STARTED_BACKEND=1
else
  log "Skipping backend start (OPENFLOW_UI_E2E_SKIP_BACKEND=1)"
fi

if ! wait_for_http "$API_BASE/health" "backend /health"; then
  log "Backend log tail:"
  tail -n 40 "$LOG_DIR/backend.log" >&2 || true
  exit 1
fi
if ! wait_for_http "$API_BASE/api/v1/ready" "backend /api/v1/ready"; then
  log "Backend log tail:"
  tail -n 40 "$LOG_DIR/backend.log" >&2 || true
  exit 1
fi

case "$TEST_MODE" in
  gallery)
    INTEGRATION_TEST="integration_test/real_product_shell_auth_gallery_test.dart"
    ;;
  full_gallery)
    INTEGRATION_TEST="integration_test/real_product_shell_full_gallery_test.dart"
    ;;
  smoke)
    INTEGRATION_TEST="integration_test/real_product_shell_auth_smoke_test.dart"
    ;;
esac

log "Running Flutter integration test: $INTEGRATION_TEST (-d $DEVICE)"
cd "$FRONTEND"
flutter pub get 2>&1 | tee "$LOG_DIR/flutter-pub-get.log"

GALLERY_DIR="$FRONTEND/build/e2e_gallery"
if [[ "$TEST_MODE" == "full_gallery" ]]; then
  rm -rf "$GALLERY_DIR"
  mkdir -p "$GALLERY_DIR"
  log "PNG capture: app container temp (printed as E2E_GALLERY_DIR=…) → copy to $GALLERY_DIR on success"
fi

set +e
flutter test "$INTEGRATION_TEST" -d "$DEVICE" \
  --dart-define=API_BASE_URL="$API_BASE" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  2>&1 | tee "$LOG_DIR/flutter-integration.log"
FLUTTER_RC=${PIPESTATUS[0]}
set -e

END_TS="$(date +%s)"
DURATION="$((END_TS - START_TS))"

if [[ "$FLUTTER_RC" -eq 0 ]]; then
  log "UI E2E passed ($TEST_MODE) in ${DURATION}s — logs: $LOG_DIR"
  if [[ "$TEST_MODE" == "full_gallery" ]]; then
    CAPTURE_DIR="$(
      grep -E 'E2E_GALLERY_DIR=' "$LOG_DIR/flutter-integration.log" 2>/dev/null \
        | tail -1 \
        | sed 's/.*E2E_GALLERY_DIR=//'
    )"
    if [[ -n "$CAPTURE_DIR" ]] && compgen -G "$CAPTURE_DIR/regular_*.png" >/dev/null; then
      cp "$CAPTURE_DIR"/regular_*.png "$GALLERY_DIR/"
    fi
    PNG_COUNT="$(find "$GALLERY_DIR" -maxdepth 1 -name 'regular_*.png' 2>/dev/null | wc -l | tr -d ' ')"
    log "Gallery PNGs: $PNG_COUNT under $GALLERY_DIR${CAPTURE_DIR:+ (from $CAPTURE_DIR)}"
  fi
  exit 0
fi

log "UI E2E failed (exit $FLUTTER_RC) after ${DURATION}s — logs: $LOG_DIR"
log "Flutter log tail:"
tail -n 60 "$LOG_DIR/flutter-integration.log" >&2 || true
exit "$FLUTTER_RC"
