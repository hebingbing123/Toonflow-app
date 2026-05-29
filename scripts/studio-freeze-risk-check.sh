#!/usr/bin/env bash
# Studio web freeze risk baseline — static heuristics for rebuild loops and layout storms.
# See frontend/lib/design_system/UI_REFACTOR_CONTEXT.md rule 26.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$ROOT/frontend/lib"

cd "$ROOT"

fail=0
warn=0

warn_line() {
  echo "WARN: $*"
  warn=$((warn + 1))
}

fail_line() {
  echo "FAIL: $*"
  fail=1
}

echo "== High-risk post-frame sites must use StudioScheduler =="
HIGH_RISK=(
  "demo/product_demo_tour_anchors.dart"
  "team_workspaces/section_helpers.dart"
  "project_editor/scripts/plan_workbench.dart"
  "shell/product_studio_steps.dart"
)
for rel in "${HIGH_RISK[@]}"; do
  f="$LIB/$rel"
  if [[ ! -f "$f" ]]; then
    fail_line "missing expected file $rel"
    continue
  fi
  if rg -q 'addPostFrameCallback' "$f" &&
    ! rg -q 'scheduleOnce(PerFrame|Until)|StudioScheduler\.' "$f"; then
    fail_line "$rel uses bare addPostFrameCallback without StudioScheduler guard"
  fi
done
if [[ "$fail" -eq 0 ]]; then
  echo "OK"
fi

echo "== debug overlay must defer clear and skip flex overflow =="
OVERLAY="$LIB/design_system/debug/debug_error_overlay_controller.dart"
POLICY="$LIB/design_system/debug/debug_error_overlay_policy.dart"
HANDLING="$LIB/bootstrap/global_error_handling.dart"
for f in "$OVERLAY" "$POLICY" "$HANDLING"; do
  if [[ ! -f "$f" ]]; then
    fail_line "missing $f"
  fi
done
if [[ -f "$POLICY" ]] && ! rg -q 'isRenderFlexOverflowError' "$POLICY"; then
  fail_line "debug_error_overlay_policy missing isRenderFlexOverflowError"
fi
if [[ -f "$OVERLAY" ]] && ! rg -q '_scheduleSnapshotUpdate' "$OVERLAY"; then
  fail_line "debug_error_overlay_controller missing deferred snapshot updates"
fi
if [[ -f "$HANDLING" ]] && rg -q 'ErrorWidget\.builder\(details\)' "$HANDLING"; then
  fail_line "global_error_handling still synchronously invokes ErrorWidget.builder(details)"
fi
if [[ "$fail" -eq 0 ]]; then
  echo "OK"
fi

echo "== Web scroll-controlled sheets use presentation split (not blanket sheetChrome dialog) =="
SHELL="$LIB/design_system/components/studio_dialog_shell.dart"
PRESENTATION="$LIB/design_system/studio_modal_presentation.dart"
if [[ ! -f "$PRESENTATION" ]]; then
  fail_line "missing studio_modal_presentation.dart"
elif [[ -f "$SHELL" ]] &&
  ! rg -q 'studioModalPresentationFor|StudioWebTallSheetDialog' "$SHELL"; then
  fail_line "studio_dialog_shell missing Web tall dialog presenter"
else
  echo "OK"
fi

echo "== scroll-controlled bottom sheets must not embed DraggableScrollableSheet =="
while IFS= read -r f; do
  rel="${f#"$ROOT"/}"
  if rg -q 'isScrollControlled:\s*true' "$f" &&
    rg -q 'return DraggableScrollableSheet|DraggableScrollableSheet\(' "$f" &&
    ! rg -q 'studio-modal:\s*draggable-allowed' "$f"; then
    fail_line "$rel uses DraggableScrollableSheet in scroll-controlled showStudioBottomSheet (migrate to fixed height scroll)"
  fi
done < <(rg -l 'showStudioBottomSheet' "$LIB" --glob '*.dart' 2>/dev/null || true)
if [[ "$fail" -eq 0 ]]; then
  echo "OK"
fi

echo "== shrinkWrap grids under project_studio (prefer SliverGrid in scroll views) =="
while IFS= read -r f; do
  rel="${f#"$ROOT"/}"
  if rg -q 'GridView\.(builder|count)|shrinkWrap:\s*true' "$f"; then
    warn_line "$rel still uses shrinkWrap GridView — verify not inside primary scroll"
  fi
done < <(find "$LIB/project_studio" -name '*.dart' -print 2>/dev/null || true)

echo "== Timer.periodic in project_studio (verify backoff on rate limits) =="
while IFS= read -r f; do
  rel="${f#"$ROOT"/}"
  if ! rg -q 'backoff|Backoff|_pollDelay|pollInterval|_pollBackoff|_jobPollBackoff' "$f"; then
    warn_line "$rel uses Timer.periodic without obvious backoff naming"
  fi
done < <(rg -l 'Timer\.periodic' "$LIB/project_studio" --glob '*.dart' 2>/dev/null || true)

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "Studio freeze risk check passed (${warn} warning(s))."
