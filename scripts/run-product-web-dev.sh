#!/usr/bin/env bash
# Start Flutter product web on a free port (avoids stale 5173) and print the URL for manual demo tour testing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND="$ROOT/frontend"
PORT="${OPENFLOW_PRODUCT_WEB_PORT:-5173}"
URL_FILE="$ROOT/scratch/product-web-dev-url.txt"

# shellcheck source=scripts/e2e/lib/flutter-web-health.sh
source "$ROOT/scripts/e2e/lib/flutter-web-health.sh"

log() { printf '[product-web-dev] %s\n' "$*"; }

if port_in_use "$PORT"; then
  PORT="$(choose_free_port "$((PORT + 1))")" || {
    log "No free port near ${OPENFLOW_PRODUCT_WEB_PORT:-5173}"
    exit 1
  }
  log "Port ${OPENFLOW_PRODUCT_WEB_PORT:-5173} busy — using $PORT"
fi

WEB_URL="http://127.0.0.1:${PORT}"
mkdir -p "$ROOT/scratch"
printf '%s\n' "$WEB_URL" >"$URL_FILE"

log "Starting Flutter web-server at $WEB_URL"
log "URL also written to $URL_FILE"
(
  cd "$FRONTEND"
  exec flutter run -d web-server \
    -t lib/main_product.dart \
    --dart-define-from-file=dart_defines.dev.json \
    --web-hostname=127.0.0.1 \
    --web-port="$PORT"
)
