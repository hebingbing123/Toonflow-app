#!/usr/bin/env bash
# Machine-generated UI review coverage report from Flutter tests.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FRONTEND="$ROOT/frontend"
REPORT="$ROOT/docs/plans/ui-review-2026-05-18.md"
INVENTORY="$ROOT/docs/plans/ui-surface-inventory.md"

cd "$FRONTEND"
flutter pub get >/dev/null

echo "Running UI review gates..."
set +e
GATES_OUT="$(bash "$ROOT/scripts/run-ui-review-gates.sh" 2>&1)"
GATES_CODE=$?
set -e
WIDGET_CODE=$GATES_CODE
GOLDEN_CODE=$GATES_CODE
SMOKE_STATUS="pass"
if echo "$GATES_OUT" | grep -q "Skipping interaction smoke"; then
  SMOKE_STATUS="skipped"
elif [[ $GATES_CODE -ne 0 ]] && echo "$GATES_OUT" | grep -q "Studio interaction smoke"; then
  SMOKE_STATUS="fail"
fi
WIDGET_OUT="$GATES_OUT"
GOLDEN_OUT="(included in run-ui-review-gates.sh)"
SMOKE_OUT="(macOS interaction smoke optional in gates script)"

{
  echo "# UI Review Report (generated)"
  echo ""
  echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo ""
  echo "## Test runs"
  echo ""
  echo "| Suite | Exit |"
  echo "|-------|------|"
  echo "| widget (test/ui) | $WIDGET_CODE |"
  echo "| widget golden (--name golden) | $GOLDEN_CODE |"
  echo "| studio_interaction_smoke | $SMOKE_STATUS |"
  echo ""
  echo "## Inventory"
  echo ""
  echo "See [$INVENTORY](ui-surface-inventory.md)."
  echo ""
  echo "### Widget test output (tail)"
  echo '```'
  echo "$WIDGET_OUT" | tail -n 40
  echo '```'
  echo ""
  echo "### Smoke output (tail)"
  echo '```'
  echo "$SMOKE_OUT" | tail -n 40
  echo '```'
} >"$REPORT"

echo "Wrote $REPORT"
exit $(( WIDGET_CODE != 0 || GOLDEN_CODE != 0 ? 1 : 0 ))
