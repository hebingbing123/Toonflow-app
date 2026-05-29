#!/usr/bin/env bash
# Studio visual debt baseline (see docs/product/ux/studio-visual-debt.md).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$ROOT/frontend/lib"

cd "$ROOT"

fail=0

echo "== Business code: no raw Material state colors =="
if rg 'Colors\.(green|red|orange|blue|grey)\b' "$LIB" --glob '*.dart' \
  --glob '!**/design_system/tokens.dart' \
  --glob '!**/design_system/theme.dart' \
  --glob '!**/product_shell/login_page.dart' 2>/dev/null; then
  echo "FAIL: raw Colors.* state hues in business code"
  fail=1
else
  echo "OK"
fi

echo "== No shrinkWrap tap targets =="
if rg 'MaterialTapTargetSize\.shrinkWrap|tapTargetSize: MaterialTapTargetSize\.shrinkWrap' \
  "$LIB" --glob '*.dart' \
  --glob '!**/design_system/theme.dart' \
  --glob '!**/design_system/components/studio_surfaces.dart' 2>/dev/null; then
  echo "FAIL: shrinkWrap tap targets"
  fail=1
else
  echo "OK"
fi

echo "== No VisualDensity.compact =="
if rg 'visualDensity: VisualDensity\.compact' "$LIB" --glob '*.dart' \
  --glob '!**/design_system/theme.dart' \
  --glob '!**/design_system/components/studio_surfaces.dart' \
  --glob '!*.backup' 2>/dev/null; then
  echo "FAIL: VisualDensity.compact still present"
  fail=1
else
  echo "OK"
fi

echo "== No raw IconButton outside studio_icon_button =="
if rg '\bIconButton\(' "$LIB" --glob '*.dart' \
  --glob '!**/design_system/components/studio_icon_button.dart' 2>/dev/null; then
  echo "FAIL: use StudioIconButton / studioAccessibleIconButton"
  fail=1
else
  echo "OK"
fi

echo "== No fontSize 10/11 outside tokens/typography =="
if rg 'fontSize:\s*(10|11)\b' "$LIB" --glob '*.dart' \
  --glob '!**/design_system/studio_typography.dart' \
  --glob '!**/design_system/tokens.dart' 2>/dev/null; then
  echo "FAIL: fontSize 10/11 in UI code"
  fail=1
else
  echo "OK"
fi

echo "== ARB en/zh key parity =="
if ! python3 "$ROOT/scripts/check_arb_locale_parity.py"; then
  echo "FAIL: app_en.arb / app_zh.arb key mismatch"
  fail=1
else
  echo "OK"
fi

echo "== Tier1 i18n hardcoded literals =="
if ! python3 "$ROOT/scripts/scan_frontend_lib_i18n.py" --check-tier1; then
  echo "FAIL: Tier1 hardcoded UI strings (see .tmp/frontend_lib_i18n_scan.md)"
  fail=1
else
  echo "OK"
fi

echo "== StudioLoadState panes use StudioAsyncDataView =="
for rel in \
  jobs/section_view.dart \
  task_center/section.dart \
  quality_reviews/section.dart; do
  if ! rg -q 'StudioAsyncDataView' "$LIB/$rel" 2>/dev/null; then
    echo "FAIL: $rel missing StudioAsyncDataView"
    fail=1
  fi
done
if [[ "$fail" -eq 0 ]]; then
  echo "OK"
fi

echo "== Token contrast (WCAG AA) =="
if ! (cd "$ROOT/frontend" && flutter test test/design_system/studio_token_contrast_test.dart --reporter compact); then
  echo "FAIL: Studio token contrast regression"
  fail=1
else
  echo "OK"
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "Studio visual debt check passed."
