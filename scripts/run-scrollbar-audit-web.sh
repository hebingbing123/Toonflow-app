#!/usr/bin/env bash
# Start harness Flutter web + Playwright screenshots for scrollbar visual audit.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND="$ROOT/frontend"
PORT="${OPENFLOW_SCROLLBAR_AUDIT_PORT:-5198}"
WEB_URL="http://127.0.0.1:${PORT}"
OUT_DIR="$ROOT/scratch/scrollbar-audit"
LOG_DIR="${OPENFLOW_SCROLLBAR_AUDIT_LOG_DIR:-$(mktemp -d /tmp/openflow-scrollbar-audit.XXXXXX)}"
FLUTTER_PID=""

# shellcheck source=scripts/e2e/lib/flutter-web-health.sh
source "$ROOT/scripts/e2e/lib/flutter-web-health.sh"

log() { printf '[scrollbar-audit] %s\n' "$*"; }

cleanup() {
  if [[ -n "$FLUTTER_PID" ]] && kill -0 "$FLUTTER_PID" 2>/dev/null; then
    log "Stopping flutter web-server (pid $FLUTTER_PID)"
    kill "$FLUTTER_PID" 2>/dev/null || true
    wait "$FLUTTER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if ! command -v node >/dev/null 2>&1; then
  log "Missing node"
  exit 127
fi

if [[ ! -d "$ROOT/scratch/node_modules/playwright" ]]; then
  log "Installing Playwright in scratch/ (one-time)"
  (cd "$ROOT/scratch" && npm install --no-audit --no-fund)
fi

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/*.png "$OUT_DIR"/*.json 2>/dev/null || true

if flutter_web_usable "$WEB_URL" "$ROOT"; then
  log "Reusing Flutter web at $WEB_URL"
else
  if port_in_use "$PORT"; then
    PORT="$(choose_free_port "$((PORT + 1))")" || exit 1
    WEB_URL="http://127.0.0.1:${PORT}"
  fi
  log "Starting harness web-server at $WEB_URL"
  (
    cd "$FRONTEND"
    flutter run -d web-server \
      -t lib/main_harness.dart \
      --web-hostname=127.0.0.1 \
      --web-port="$PORT" \
      >"$LOG_DIR/flutter-web.log" 2>&1
  ) &
  FLUTTER_PID=$!
  wait_for_flutter_web "$WEB_URL" 120 "$ROOT" || {
    log "Flutter web not ready; tail $LOG_DIR/flutter-web.log"
    tail -50 "$LOG_DIR/flutter-web.log" >&2 || true
    exit 1
  }
fi

log "Running Playwright scrollbar audit → $OUT_DIR"
export WEB_URL OUT_DIR
node "$ROOT/scripts/e2e/scrollbar-audit-web.mjs"

log "PASS — screenshots: $OUT_DIR"
ls -la "$OUT_DIR"/*.png 2>/dev/null || true
