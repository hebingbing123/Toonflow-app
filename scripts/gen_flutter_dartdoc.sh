#!/usr/bin/env bash
# Generate dartdoc for the public design_system surface (27.4).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/api/flutter-design-system"
cd "$ROOT/frontend"

flutter pub get >/dev/null
dart doc --output "$OUT" lib/design_system

echo "dartdoc written to $OUT/index.html"
