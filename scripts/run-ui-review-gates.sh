#!/usr/bin/env bash
# Local/CI UI review gates: widget tests, goldens, export-history dialog suite.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FRONTEND="$ROOT/frontend"

cd "$FRONTEND"
flutter pub get

echo "== Studio visual debt baseline =="
bash "$ROOT/scripts/studio-visual-debt-check.sh"

echo "== UI widget + dialog tests (non-golden) =="
# Exclude *golden* files and desktop layout gallery (golden tests inside filename).
# shellcheck disable=SC2046
flutter test test/support/ test/dialogs/ $(find test/ui -name '*_test.dart' ! -name '*golden*' ! -name 'desktop_layout_widget_gallery_test.dart' ! -name 'help_hub_studio_test.dart' | sort)
flutter test test/ui/help_hub_studio_test.dart --plain-name 'help_hub shows seeded webhook and billing audit cards'

echo "== UI widget goldens (ui_gallery + desktop_layouts) =="
if [[ "$(uname -s)" == "Darwin" ]]; then
  flutter test test/ui/ --name golden
else
  echo "Skipping goldens on $(uname -s) (font raster differs from macOS baselines)."
fi

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
