#!/usr/bin/env bash
# Full 15-stop demo tour E2E: screenshots per step + JSON report + unit tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND="$ROOT/frontend"
SCRATCH="$ROOT/scratch"
PORT="${OPENFLOW_DEMO_TOUR_WEB_PORT:-5173}"
WEB_URL="http://127.0.0.1:${PORT}"
OUT_DIR="$ROOT/scratch/demo-tour-e2e-full"
LOG_DIR="${OPENFLOW_DEMO_TOUR_LOG_DIR:-$(mktemp -d /tmp/openflow-demo-tour-full.XXXXXX)}"
FLUTTER_PID=""

# shellcheck source=scripts/e2e/lib/flutter-web-health.sh
source "$ROOT/scripts/e2e/lib/flutter-web-health.sh"

log() { printf '[demo-tour-full] %s\n' "$*"; }

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
}

ensure_flutter_web_target() {
  local initial_port="$PORT"

  if [[ "${OPENFLOW_DEMO_TOUR_SKIP_SERVER:-}" == "1" ]]; then
    if flutter_web_usable "$WEB_URL" "$ROOT"; then
      log "Using existing Flutter web at $WEB_URL (SKIP_SERVER=1)"
      return 0
    fi
    log "SKIP_SERVER=1 but $WEB_URL is not Flutter-ready (wrong process on port?)"
    log "Run without SKIP_SERVER or start: cd frontend && flutter run -d web-server -t lib/main_product.dart --dart-define-from-file=dart_defines.dev.json --web-port=$PORT"
    exit 1
  fi

  if [[ "${OPENFLOW_DEMO_TOUR_REUSE_SERVER:-0}" == "1" ]]; then
    if flutter_web_usable "$WEB_URL" "$ROOT"; then
      log "Reusing Flutter web at $WEB_URL"
      return 0
    fi
    log "OPENFLOW_DEMO_TOUR_REUSE_SERVER=1 but $WEB_URL is not Flutter-ready (Playwright preflight failed)"
    exit 1
  fi

  # Port already taken (often a stale/broken dev server on 5173) — never attach E2E to it.
  if port_in_use "$initial_port"; then
    log "Port $initial_port is busy — starting isolated Flutter web-server"
    PORT="$(choose_free_port "$((initial_port + 1))")" || {
      log "No free port available near ${OPENFLOW_DEMO_TOUR_WEB_PORT:-5173}"
      exit 1
    }
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

if [[ ! -d "$SCRATCH/node_modules/playwright" ]]; then
  log "Installing Playwright in scratch/"
  (cd "$SCRATCH" && npm install --no-audit --no-fund)
fi

ensure_flutter_web_target

log "Unit tests (demo/)"
(cd "$FRONTEND" && flutter test test/demo/)

log "Full tour Playwright (24 beats, screenshots → $OUT_DIR)"
export WEB_URL OUT_DIR DEMO_TOUR_NAV_WAIT_MS="${DEMO_TOUR_NAV_WAIT_MS:-5500}"
node "$ROOT/scripts/e2e/demo-tour-web-full.mjs"

mkdir -p "$ROOT/scratch"
printf '%s\n' "$WEB_URL" >"$ROOT/scratch/demo-tour-last-web-url.txt"
log "DONE — open $OUT_DIR/full-tour-report.json and step-*.png"
log "WEB_URL=$WEB_URL (also scratch/demo-tour-last-web-url.txt)"
printf '%s\n' "$WEB_URL" >"$OUT_DIR/last-web-url.txt"
