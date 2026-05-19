#!/usr/bin/env bash
# Local/CI UI review gates: widget tests, goldens, export-history dialog suite.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FRONTEND="$ROOT/frontend"

cd "$FRONTEND"
flutter pub get

echo "== UI widget + dialog tests =="
flutter test test/ui/ test/support/ test/dialogs/

echo "== UI widget goldens (ui_gallery + desktop_layouts) =="
flutter test test/ui/ --name golden

echo "== Export history dialog suite =="
flutter test test/export_history_dialog_test.dart

echo "== Product shell utility routes =="
flutter test test/product_shell/router_utility_integration_test.dart

if [[ "$(uname -s)" == "Darwin" ]]; then
  if flutter devices 2>/dev/null | grep -qi 'macos'; then
    echo "== Studio interaction smoke (macOS) =="
    flutter test integration_test/studio_interaction_smoke_test.dart -d macos
  else
    echo "== Skipping interaction smoke (no macOS desktop device) =="
  fi
else
  echo "== Skipping interaction smoke (non-macOS host) =="
fi

echo "UI review gates passed."
