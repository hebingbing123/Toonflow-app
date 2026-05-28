#!/usr/bin/env bash
# UI/UX audit E2E gallery — full RepaintBoundary PNGs at 1920×1080 and 375×667.
#
# Usage (repo root):
#   bash scripts/run-ui-ux-audit-e2e.sh
#
# Env (same as run-ui-e2e.sh):
#   OPENFLOW_UI_E2E_SKIP_RESET=1
#   OPENFLOW_UI_E2E_SKIP_BACKEND=1
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND="$ROOT/frontend"
# shellcheck disable=SC1091
source "$ROOT/scripts/local_test_env.sh"

export OPENFLOW_UI_E2E_SKIP_RESET="${OPENFLOW_UI_E2E_SKIP_RESET:-1}"
export OPENFLOW_UI_E2E_SKIP_BACKEND="${OPENFLOW_UI_E2E_SKIP_BACKEND:-1}"

PORT="${OPENFLOW_UI_E2E_PORT:-8666}"
DEVICE="${OPENFLOW_UI_E2E_DEVICE:-macos}"
API_BASE="http://127.0.0.1:${PORT}"
AUDIT_OUT="$ROOT/.codex/skills/ui-ux-audit/output"
BUILD_OUT="$FRONTEND/build/ui_ux_audit_e2e"
LOG_DIR="${OPENFLOW_UI_E2E_LOG_DIR:-$(mktemp -d /tmp/openflow-ui-ux-audit-e2e.XXXXXX)}"
mkdir -p "$LOG_DIR" "$BUILD_OUT/desktop" "$BUILD_OUT/mobile" "$AUDIT_OUT/e2e/desktop" "$AUDIT_OUT/e2e/mobile"

log() { printf '[ui-ux-audit-e2e] %s\n' "$*"; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  log "WARN: macOS desktop device recommended; DEVICE=$DEVICE"
fi

SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:64421}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"

if ! curl -sf "$API_BASE/health" >/dev/null; then
  log "Backend not up at $API_BASE — start with: cd backend && cargo run"
  exit 1
fi

if ! curl -sf "$SUPABASE_URL/auth/v1/health" >/dev/null; then
  log "Supabase auth not up at $SUPABASE_URL — start with: supabase start"
  exit 1
fi

log "Running ui_ux_audit_gallery_test.dart (-d $DEVICE) → $BUILD_OUT/ (then copy to audit output)"
cd "$FRONTEND"
flutter pub get 2>&1 | tee "$LOG_DIR/flutter-pub-get.log"

rm -rf "$BUILD_OUT/desktop" "$BUILD_OUT/mobile"
mkdir -p "$BUILD_OUT/desktop" "$BUILD_OUT/mobile"

set +e
FLUTTER_RC=0
for vp in mobile desktop; do
  log "Running viewport: $vp"
  flutter test integration_test/ui_ux_audit_gallery_test.dart -d "$DEVICE" \
    --timeout=none \
    --plain-name "@ ${vp} " \
    --dart-define=API_BASE_URL="$API_BASE" \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --dart-define=OPENFLOW_UI_UX_AUDIT_OUTPUT="$BUILD_OUT" \
    --dart-define=OPENFLOW_SCREENSHOT_MODE=true \
    2>&1 | tee -a "$LOG_DIR/flutter-integration.log"
  vp_rc=${PIPESTATUS[0]}
  if [[ "$vp_rc" -ne 0 ]]; then
    FLUTTER_RC="$vp_rc"
    log "WARN: $vp viewport failed (exit $vp_rc)"
  fi
done
set -e

# Copy any PNGs produced even when test fails late (partial gallery).
if [[ "$FLUTTER_RC" -ne 0 ]]; then
  log "WARN: flutter test exit $FLUTTER_RC — copying partial PNGs if present"
fi
CONTAINER_TMP="${HOME}/Library/Containers/com.openflow.openflowApp/Data/tmp"
copy_audit_pngs() {
  local vp="$1"
  local capture_dir="${CONTAINER_TMP}/openflow_ui_ux_audit_${vp}"
  local log_line
  log_line="$(grep "^E2E_AUDIT_DIR=.*openflow_ui_ux_audit_${vp}" "$LOG_DIR/flutter-integration.log" 2>/dev/null | tail -1 || true)"
  if [[ -z "$log_line" ]]; then
    log_line="$(grep "^E2E_AUDIT_DIR=" "$LOG_DIR/flutter-integration.log" 2>/dev/null | grep "_${vp}\$" | tail -1 || true)"
  fi
  if [[ -n "$log_line" ]]; then
    capture_dir="${log_line#E2E_AUDIT_DIR=}"
  fi
  if [[ ! -d "$capture_dir" ]]; then
    capture_dir="/tmp/openflow_ui_ux_audit_${vp}"
  fi
  if [[ -d "$BUILD_OUT/${vp}" ]] && compgen -G "${BUILD_OUT}/${vp}/*.png" >/dev/null; then
    cp -f "${BUILD_OUT}/${vp}"/*.png "$AUDIT_OUT/e2e/${vp}/" 2>/dev/null || true
  fi
  local copied=0
  for pattern in 'regular_*.png' 'interaction_*.png' 'overlay_*.png' 'audit_manifest.json'; do
    if compgen -G "${capture_dir}/${pattern}" >/dev/null; then
      cp -f "${capture_dir}"/${pattern} "$AUDIT_OUT/e2e/${vp}/"
      copied=$((copied + $(find "${capture_dir}" -maxdepth 1 -name "${pattern}" | wc -l | tr -d ' ')))
    fi
  done
  if [[ "$copied" -gt 0 ]]; then
    log "Copied ${vp} (${copied} PNGs) from $capture_dir"
  else
    log "WARN: no PNGs in $capture_dir for $vp"
  fi
}

for vp in mobile desktop; do
  copy_audit_pngs "$vp"
done

DESKTOP_REG="$(find "$AUDIT_OUT/e2e/desktop" -maxdepth 1 -name 'regular_*.png' 2>/dev/null | wc -l | tr -d ' ')"
MOBILE_REG="$(find "$AUDIT_OUT/e2e/mobile" -maxdepth 1 -name 'regular_*.png' 2>/dev/null | wc -l | tr -d ' ')"
DESKTOP_INT="$(find "$AUDIT_OUT/e2e/desktop" -maxdepth 1 -name 'interaction_*.png' 2>/dev/null | wc -l | tr -d ' ')"
MOBILE_INT="$(find "$AUDIT_OUT/e2e/mobile" -maxdepth 1 -name 'interaction_*.png' 2>/dev/null | wc -l | tr -d ' ')"
log "PNG counts (audit output): desktop routes=$DESKTOP_REG interactions=$DESKTOP_INT mobile routes=$MOBILE_REG interactions=$MOBILE_INT"
log "Build dir: $BUILD_OUT"
log "Logs: $LOG_DIR"

if [[ "$FLUTTER_RC" -ne 0 ]]; then
  tail -n 40 "$LOG_DIR/flutter-integration.log" >&2 || true
  exit "$FLUTTER_RC"
fi

log "Optional: bash scripts/analyze-ui-ux-audit-screenshots.sh \"$AUDIT_OUT/e2e\""

exit 0
