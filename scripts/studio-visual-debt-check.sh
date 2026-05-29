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

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "Studio visual debt check passed."
