#!/usr/bin/env bash
# Full 15-stop product demo tour on Flutter desktop (default: macOS integration_test).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND="$ROOT/frontend"
DEVICE="${OPENFLOW_DEMO_TOUR_DEVICE:-macos}"

log() { printf '[demo-tour-desktop-full] %s\n' "$*"; }

if ! command -v flutter >/dev/null 2>&1; then
  log "flutter not found on PATH"
  exit 1
fi

device_available() {
  (cd "$FRONTEND" && flutter devices --machine 2>/dev/null) | node -e "
    const id = process.argv[1];
    const rows = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    process.exit(rows.some((d) => d.id === id) ? 0 : 1);
  " "$DEVICE"
}
if ! device_available; then
  log "Flutter device '$DEVICE' not available. Run: cd frontend && flutter devices"
  exit 1
fi

log "Unit tests (demo/)"
(cd "$FRONTEND" && flutter test test/demo/)

log "Demo tour modes (manual simulated clicks + autoplay) on $DEVICE"
(cd "$FRONTEND" && flutter test integration_test/product_demo_tour_modes_test.dart \
  -d "$DEVICE" \
  --dart-define-from-file=dart_defines.dev.json)

log "DONE — manual + autoplay demo tour passed on $DEVICE"
