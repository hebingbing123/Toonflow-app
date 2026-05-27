#!/usr/bin/env bash
# Automated Web E2E for product demo tour (Playwright + optional Flutter unit tests).
# No manual clicks — starts web-server if needed, runs headless browser.
#
# Usage (repo root):
#   bash scripts/run-demo-tour-web-e2e.sh
#   DEMO_TOUR_TEST_AUTOPLAY=1 bash scripts/run-demo-tour-web-e2e.sh
#   OPENFLOW_DEMO_TOUR_SKIP_SERVER=1 bash scripts/run-demo-tour-web-e2e.sh
#
# Env:
#   OPENFLOW_DEMO_TOUR_WEB_PORT   default 5173
#   OPENFLOW_DEMO_TOUR_SKIP_SERVER 1 = do not start flutter (must be Flutter-ready)
#   OPENFLOW_DEMO_TOUR_REUSE_SERVER 1 = reuse existing Flutter on WEB_URL
#   DEMO_TOUR_TEST_AUTOPLAY       1 = also test 自动导览
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND="$ROOT/frontend"
SCRATCH="$ROOT/scratch"
PORT="${OPENFLOW_DEMO_TOUR_WEB_PORT:-5173}"
WEB_URL="http://127.0.0.1:${PORT}"
OUT_DIR="$ROOT/scratch/demo-tour-e2e"
LOG_DIR="${OPENFLOW_DEMO_TOUR_LOG_DIR:-$(mktemp -d /tmp/openflow-demo-tour-e2e.XXXXXX)}"
FLUTTER_PID=""

# shellcheck source=scripts/e2e/lib/flutter-web-health.sh
source "$ROOT/scripts/e2e/lib/flutter-web-health.sh"

log() { printf '[demo-tour-e2e] %s\n' "$*"; }

cleanup() {
  if [[ -n "$FLUTTER_PID" ]] && kill -0 "$FLUTTER_PID" 2>/dev/null; then
    log "Stopping flutter web-server (pid $FLUTTER_PID)"
    kill "$FLUTTER_PID" 2>/dev/null || true
    wait "$FLUTTER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

port_in_use() {
  lsof -ti "tcp:$1" >/dev/null 2>&1
}

choose_free_port() {
  local start="$1"
  local candidate="$start"
  local i
  for i in $(seq 1 40); do
    if ! port_in_use "$candidate"; then
      printf '%s' "$candidate"
      return 0
    fi
    candidate=$((candidate + 1))
  done
  return 1
}

start_flutter_web_server() {
  log "Starting flutter web-server on $WEB_URL"
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
  wait_for_flutter_web "$WEB_URL" 120 "$ROOT" || {
    log "Flutter web did not become ready; tail $LOG_DIR/flutter-web.log"
    tail -40 "$LOG_DIR/flutter-web.log" >&2 || true
    exit 1
  }
  log "Flutter web ready at $WEB_URL"
}

ensure_flutter_web_target() {
  local initial_port="$PORT"

  if [[ "${OPENFLOW_DEMO_TOUR_SKIP_SERVER:-}" == "1" ]]; then
    if flutter_web_usable "$WEB_URL" "$ROOT"; then
      log "Using existing Flutter web at $WEB_URL (SKIP_SERVER=1)"
      return 0
    fi
    log "SKIP_SERVER=1 but $WEB_URL is not Flutter-ready (Playwright preflight failed)"
    exit 1
  fi

  if [[ "${OPENFLOW_DEMO_TOUR_REUSE_SERVER:-0}" == "1" ]]; then
    if flutter_web_usable "$WEB_URL" "$ROOT"; then
      log "Reusing Flutter web at $WEB_URL"
      return 0
    fi
    log "OPENFLOW_DEMO_TOUR_REUSE_SERVER=1 but $WEB_URL is not Flutter-ready"
    exit 1
  fi

  if port_in_use "$initial_port"; then
    log "Port $initial_port is busy — starting isolated Flutter web-server"
    PORT="$(choose_free_port "$((initial_port + 1))")" || exit 1
    WEB_URL="http://127.0.0.1:${PORT}"
    start_flutter_web_server
    return 0
  fi

  if flutter_web_usable "$WEB_URL" "$ROOT"; then
    log "Flutter web already up at $WEB_URL"
    return 0
  fi

  start_flutter_web_server
}

if ! command -v node >/dev/null 2>&1; then
  log "Missing node"
  exit 127
fi

if [[ ! -d "$SCRATCH/node_modules/playwright" ]]; then
  log "Installing Playwright in scratch/ (one-time)"
  (cd "$SCRATCH" && npm install --no-audit --no-fund)
fi

ensure_flutter_web_target

log "Running Flutter demo tour unit tests"
(
  cd "$FRONTEND"
  flutter test test/demo/
)

log "Running Playwright demo tour E2E"
export WEB_URL OUT_DIR
node "$ROOT/scripts/e2e/demo-tour-web.mjs"

log "PASS — artifacts: $OUT_DIR"
log "WEB_URL=$WEB_URL"
if [[ -f "$OUT_DIR/result.json" ]]; then
  cat "$OUT_DIR/result.json"
fi
