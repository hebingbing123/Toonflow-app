# UI/UX burn-down progress (2026-05-23)

## Wave summary

| Wave | Action | Result |
|------|--------|--------|
| **A** | `ui_audit fix` spacing (×2) + `studioShadowColor` for 17 section shadows | 651 → 304 full findings |
| **B** | `audit-config-burn-down.yaml` (maxFindings 10000) + import/shadow token fixes | Full inventory **307** findings |
| **C** | quick preset + CI unchanged | **0** quick findings; `flutter analyze` clean |

## Wave 4 (componentConsistency) — 2026-05-23

- Added [`studio_chip.dart`](../../frontend/lib/design_system/components/studio_chip.dart): `StudioChip`, `StudioActionChip`, `StudioFilterChip`, `StudioChoiceChip`, `StudioInputChip`
- Token radii: `radiusDense` (8), `radiusComfort` (12), `radiusSheet` (28)
- Migrated ~89 files: Material chips → Studio* chips; `BorderRadius.circular(8|12|…)` → spacing tokens
- `part` libraries keep raw `Chip` (no import in parts)

Re-run: `dart run ui_audit:ui_audit --config=../../.kiro/audit-config-burn-down.yaml`

| Metric | Before wave 4 | After wave 4 |
|--------|---------------|--------------|
| Full burn-down | 307 | **131** |
| Quick preset | 0 | **0** |

After wave 4, remaining full findings are mostly **responsiveness**, **emptyStates**, residual **spacing/color**, and low-severity **Card** duplicates.

## Wave 5 (responsive + color + chips + cards) — 2026-05-23

- Added `studioConstrainedDialogWidth` in [`layout_breakpoints.dart`](../../frontend/lib/design_system/layout_breakpoints.dart); migrated dialog `width: ≥400` across launchers, shorts, compliance, help hub, etc.
- Extended audit allowlists: `design_system/` shadow colors, `login_page` branding, `preview_player` letterbox black, `ReviewPack` glass hints.
- `home_page` / `team_workspaces` / help-hub `part` files: `StudioChip` / `StudioFilterChip` via parent imports.
- Product color pass: shadows → `studioShadowColor`, snackbars → `onPrimary`, account/global_search tokens.
- Raw `Card` → `StudioCard` in notifications, art step, short-video version UI.

| Metric | After wave 4 | After wave 5 |
|--------|--------------|--------------|
| Full burn-down | 131 | **21** |
| Quick preset | 0 | **0** |
| `flutter analyze` | clean | **clean** |

Remaining **21**: 13 spacing, 4 emptyStates, 4 duplicate custom card classes (agent/search/job-queue).

## Wave 6 (spacing + false-positive cleanup) — 2026-05-23

- Spacing: legacy `10`/`12`/`14`/`8` → `StudioLayoutSpacing.*` / `StudioSpacing.xs` in callouts, global search palette, script tabs, product shell, short-video dialogs.
- Empty states: palette uses `StudioEmptyState`; home hub uses `SingleChildScrollView`; analyzer skips static shell/setup scroll regions.
- Component audit: allowlist domain cards (`SearchResultCard`, agent workspace cards, `JobQueueStatsCard`).

| Metric | After wave 5 | After wave 6 |
|--------|--------------|--------------|
| Full burn-down | 21 | **0** |
| Quick preset | 0 | **0** |

## Commands

```bash
cd tools/ui_audit
dart run ui_audit:ui_audit --config=../../.kiro/audit-config-burn-down.yaml
dart run ui_audit:ui_audit fix --report=../../.kiro/audit-reports/audit-<ts>.json --dry-run
dart run ui_audit:ui_audit report --trend
```

## Next burn-down (optional)

1. Replace raw `Chip` with `StudioChip` / filter chip pattern (componentConsistency batch).
2. Normalize border radii to `StudioSpacing.radiusCard` / `radiusButton`.
3. Module order: `short_video_space` → `project_editor` → `project_studio`.
