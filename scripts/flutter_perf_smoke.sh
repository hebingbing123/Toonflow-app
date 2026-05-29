#!/usr/bin/env bash
# Profile-mode widget smoke for dev perf triage (26.3).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/frontend"
echo "== flutter_perf_smoke (profile) =="
flutter test test/design_system/studio_token_contrast_test.dart --profile --reporter compact
echo "For deeper traces: flutter run --profile -d macos"
