# Studio UI refactor context (Composer / Agent)

Attach these files before any UI/UX change:

- [`theme.dart`](theme.dart) — `buildStudioDarkTheme` / `buildStudioLightTheme`, `PageTransitionsTheme`
- [`tokens.dart`](tokens.dart) — `StudioSpacing`, `StudioLayoutSpacing`, `StudioTokens`
- [`../platform/studio_load_state.dart`](../platform/studio_load_state.dart) — pane load states
- [`ASYNC_LOADING.md`](ASYNC_LOADING.md) — loading / empty / error matrix
- [`docs/product/ux/studio-visual-guidelines.md`](../../../docs/product/ux/studio-visual-guidelines.md)

## Rules

1. Colors: `StudioTokens.of(context)` / `Theme.of(context).colorScheme` — no `Colors.*` or `Color(0x…)` in feature code.
2. Typography: `StudioTypography` + `studio_*Style` helpers in [`components/studio_text_styles.dart`](components/studio_text_styles.dart).
3. Spacing: 8px grid (`StudioSpacing`, `StudioLayoutSpacing`).
4. Pane loading: `StudioAsyncDataView` + skeletons — not full-pane `CircularProgressIndicator`.
5. Buttons in dialogs: `studioFormPrimaryButtonStyle` / `studioFormDestructivePrimaryButtonStyle`.
6. Dense icon actions: `studioFormTextButtonIconStyle` / `studioUtilityIconButtonStyle`.
7. Errors: `describeUserVisibleApiErrorResolved` — never `e.toString()` in UI.
8. Desktop pointer: [`ix/studio_pointer.dart`](ix/studio_pointer.dart) when adding hover/cursor to custom tappables.

## Verification

```bash
bash scripts/studio-visual-debt-check.sh
cd frontend && flutter analyze
cd frontend && flutter test test/ui/studio_async_sections_test.dart
```

E2E UI audit: `bash scripts/run-ui-ux-audit-e2e.sh` (see [`docs/plans/ui-ux-audit-round-2026-05-27.md`](../../../docs/plans/ui-ux-audit-round-2026-05-27.md)).
