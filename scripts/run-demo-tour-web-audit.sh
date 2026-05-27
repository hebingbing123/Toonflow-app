#!/usr/bin/env bash
# Demo tour Web audit: desktop + mobile viewports, 24 beats each.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND="$ROOT/frontend"
SCRATCH="$ROOT/scratch"
PORT="${OPENFLOW_DEMO_TOUR_WEB_PORT:-5173}"
LOG_DIR="${OPENFLOW_DEMO_TOUR_LOG_DIR:-$(mktemp -d /tmp/openflow-demo-tour-audit.XXXXXX)}"

# shellcheck source=scripts/e2e/lib/flutter-web-health.sh
source "$ROOT/scripts/e2e/lib/flutter-web-health.sh"

log() { printf '[demo-tour-audit] %s\n' "$*"; }

cleanup() {
  if [[ -n "${FLUTTER_PID:-}" ]] && kill -0 "$FLUTTER_PID" 2>/dev/null; then
    kill "$FLUTTER_PID" 2>/dev/null || true
    wait "$FLUTTER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [[ ! -d "$SCRATCH/node_modules/playwright" ]]; then
  (cd "$SCRATCH" && npm install --no-audit --no-fund)
fi

if ! flutter_web_usable "http://127.0.0.1:${PORT}" "$ROOT" 2>/dev/null; then
  log "Starting Flutter web on port $PORT"
  (
    cd "$FRONTEND"
    flutter run -d web-server \
      -t lib/main_product.dart \
      --dart-define-from-file=dart_defines.dev.json \
      --web-hostname=127.0.0.1 \
      --web-port="$PORT" \
      >"$LOG_DIR/flutter-web.log" 2>&1
  ) &
  FLUTTER_PID=$!
  wait_for_flutter_web "http://127.0.0.1:${PORT}" 180 "$ROOT"
else
  log "Reusing Flutter web at http://127.0.0.1:${PORT}"
  WEB_URL="http://127.0.0.1:${PORT}"
fi

WEB_URL="${WEB_URL:-http://127.0.0.1:${PORT}}"

run_viewport() {
  local label="$1"
  local width="$2"
  local height="$3"
  local out="$SCRATCH/demo-tour-audit-${label}"
  log "Playwright tour ($label ${width}x${height}) → $out"
  OUT_DIR="$out" \
    WEB_URL="$WEB_URL" \
    DEMO_TOUR_NAV_WAIT_MS="${DEMO_TOUR_NAV_WAIT_MS:-4500}" \
    DEMO_TOUR_VIEWPORT_WIDTH="$width" \
    DEMO_TOUR_VIEWPORT_HEIGHT="$height" \
    node "$ROOT/scripts/e2e/demo-tour-web-full.mjs"
}

export WEB_URL
run_viewport "desktop-1440" 1440 1000
run_viewport "mobile-375" 375 812

log "DONE — screenshots under scratch/demo-tour-audit-*"
