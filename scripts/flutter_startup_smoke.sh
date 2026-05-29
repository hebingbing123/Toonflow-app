#!/usr/bin/env bash
# Cold-start smoke: time to first `flutter test` compile (29.1 baseline helper).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/frontend"
echo "== flutter_startup_smoke =="
START=$(date +%s)
flutter test test/design_system/studio_token_contrast_test.dart --reporter compact >/dev/null
END=$(date +%s)
echo "token_contrast_test elapsed: $((END - START))s"
echo "Log locally and compare across PRs; not a CI gate."
