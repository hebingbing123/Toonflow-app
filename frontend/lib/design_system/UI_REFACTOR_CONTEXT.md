# Studio UI refactor context (Composer / Agent)

Attach these files before any UI/UX change:

- [`theme.dart`](theme.dart) — `buildStudioDarkTheme` / `buildStudioLightTheme`, `PageTransitionsTheme`
- [`tokens.dart`](tokens.dart) — `StudioSpacing`, `StudioLayoutSpacing`, `StudioTokens`
- [`../platform/studio_load_state.dart`](../platform/studio_load_state.dart) — pane load states
- [`ASYNC_LOADING.md`](ASYNC_LOADING.md) — loading / empty / error matrix
- [`docs/product/ux/studio-visual-guidelines.md`](../../../docs/product/ux/studio-visual-guidelines.md)
- [`docs/plans/flutter-ui-ux-refactor-18-phases.md`](../../../docs/plans/flutter-ui-ux-refactor-18-phases.md) — 18 阶段对照与下一批范围
- [`docs/plans/flutter-ui-ux-async-cpi-audit.md`](../../../docs/plans/flutter-ui-ux-async-cpi-audit.md) — CPI 审计基线
- [`docs/plans/flutter-ui-ux-breakpoint-mapping.md`](../../../docs/plans/flutter-ui-ux-breakpoint-mapping.md) — Kiro ↔ 产品断点对照
- [`studio_elevation.dart`](studio_elevation.dart) / [`studio_motion.dart`](studio_motion.dart) — 阴影与动效时长真源

## Rules

1. Colors: `StudioTokens.of(context)` / `Theme.of(context).colorScheme` — no `Colors.*` or `Color(0x…)` in feature code.
2. Typography: `StudioTypography` + `studio_*Style` helpers in [`components/studio_text_styles.dart`](components/studio_text_styles.dart).
3. Spacing: 8px grid (`StudioSpacing`, `StudioLayoutSpacing`).
4. Pane loading: `StudioAsyncDataView` + skeletons — not full-pane `CircularProgressIndicator`.
5. Buttons in dialogs: `studioFormPrimaryButtonStyle` / `studioFormDestructivePrimaryButtonStyle`.
6. Dense icon actions: `studioFormTextButtonIconStyle` / `studioUtilityIconButtonStyle`.
7. Errors: `describeUserVisibleApiErrorResolved` — never `e.toString()` in UI.
8. Desktop pointer: [`ix/studio_pointer.dart`](ix/studio_pointer.dart) when adding hover/cursor to custom tappables.
9. Submit debounce: [`studio_interaction_timing.dart`](studio_interaction_timing.dart) + [`components/studio_debounced_action.dart`](components/studio_debounced_action.dart) — `StudioPrimaryButton` / `showStudioConfirmDialog` (optional `onConfirmAction`); live search uses `searchThrottle` (300ms).
10. Icon-only actions: [`components/studio_icon_button.dart`](components/studio_icon_button.dart) — `StudioIconButton` / `StudioUtilityIconButton` / `studioAccessibleIconButton`; **no** raw `IconButton` in `lib/` (enforced by `studio-visual-debt-check.sh`).
11. Metric typography: `studioMetricTextStyle` / `studioMetricTitleStyle` + `StudioMetricSwitch` for animated metric changes.
12. Repaint hotspots: `StudioRepaintBoundary` on tray spinners / toast chrome / short-video batch+export CPIs.
13. Connectivity: `StudioConnectivityBanner` when `studioLooksLikeConnectivityError(error)` (product shell list pane).
14. Metric chips: `StudioMetricSwitch` + `studioMetricTextStyle` for numeric labels (billing, short-video overview).
15. Form keyboard: `StudioFormKeyboardScope` + `studioFormFieldAcceptsEnterSubmit` + `studioFocusedTextField` — Enter submits on single-line fields; multiline keeps newline. **`StudioAlertDialog`**: one single-line `TextField` in `content` auto-binds Enter to the trailing `FilledButton` (`studioResolveAlertDialogEnterSubmit`); multi-field dialogs need explicit `onEnterSubmit` or `enterSubmitEnabled: false`. **Project editor**: settings dialog (`editor_dialog_content`), asset create/edit/filter/delete/link/clip-upload/edit-image launchers, images workbench, corner-scape filter, generation dialog, scripts batch + workbench + **plan workbench**, novel import/create/edit/delete/search sections, novel events, audit/members search (`onSubmitted`). **Exempt**: `candidate_status_dialog` (dropdown-only). **Project studio**: wizard, art brief/panel, novel inline import, crawl auth, crawl login webview. **Elsewhere**: script edit/batch/edit-image, login, API keys, vendors, settings, team/account, admin, quality/task, compliance, harness auth. **Global search**: `onSubmitted` + shortcuts only (never wrap `global_search_bar`). **Notifications**: filter + `TextInputAction.search` / `onSubmitted`.
16. Hero: `StudioHero` wraps `HeroMode(enabled: route.isCurrent)` so background routes in the stack do not duplicate tags (projects grid ↔ studio header).
17. Truncated copy: prefer `StudioEllipsisTooltipText` over bare `Text` + ellipsis when full string helps (search titles, pane headers).
18. Narrow projects harness: `projects/section.dart` stacks title/actions below `kStudioPipelineInlineMinWidth` (760px content pane).
19. Unsaved back guard: `StudioDirtyPopGuard` on wizards, script editor, art step, publish copy editor (`popBlocked` while saving).
20. Timers: cancel in `dispose` (export progress/history, assembly poll, filter debounce).
21. Pane title + prefs menu: [`components/studio_pane_header.dart`](components/studio_pane_header.dart) — `StudioPaneTitleMenuRow` (stacks below `kStudioPipelineInlineMinWidth`); multi-action pane headers may use `_buildNotificationsPaneHeaderRow`-style `Wrap` for trailing buttons; toolbars with actions use `StudioPaneToolbar` / `StudioPaneHeader`.
22. Glass perf: `--dart-define=STUDIO_GLASS=false` disables blur; `--dart-define=STUDIO_GLASS_SHADER=true` uses `shaders/studio_glass_blur.frag` via [`studio_glass_shader.dart`](studio_glass_shader.dart).
23. Scrollbars: `StudioScrollBehavior` on `MaterialApp` (`studio_app.dart`) — visible thumbs when width &gt; `kStudioHandsetMaxWidth`; wrap ad-hoc scroll views with `StudioScrollbar` only when not under `MaterialApp`.
24. Raw `GestureDetector`: only `studio_tap.dart`, `debug_overlay_widget.dart`, `build_product_shell.dart` (see visual guidelines).
25. `TextButton.icon` in product UI: `studioFormTextButtonIconStyle` — no bare `VisualDensity.compact` in business `lib/`.
26. Post-frame guards: use [`studio_scheduler.dart`](studio_scheduler.dart) (`StudioScheduler.scheduleOncePerFrame` / `scheduleOnceUntil`) — **never** bare `addPostFrameCallback` + `setState` inside `build`, `LayoutBuilder`, or `StatefulBuilder` builders (web tab freeze risk).
27. Data display: prefer `StudioTable` / `StudioTree` / `StudioTimeline` / `StudioBreadcrumb` from [`components/studio.dart`](components/studio.dart) for new admin/reporting surfaces.
28. Error routing: `classifyStudioError` + `studioErrorIsRetryable` in [`utils/error_handling.dart`](../utils/error_handling.dart); user copy via `formatStudioUserError` / `describeUserVisibleApiErrorResolved`.
29. Modal focus: `showStudioDialog` and `showStudioBottomSheet` wrap content in `StudioFocusTrap`.
30. Virtual lists: `StudioList` / `StudioGrid` with `loading: true` → skeleton; drawer via `showStudioDrawer`.
31. File upload affordance: `StudioFileDropZone` — browse (`file_picker`) + desktop OS drop (`studio_native_file_drop` / `desktop_drop`).
32. Offline pane cache: `StudioOfflineCache` on connectivity failure (jobs queue exemplar).
33. Optimistic UI: `studioRunOptimisticMutation` — notifications; jobs/task center; team workspace archive/switch; API keys; content compliance queue; short-video batch archive/schedule. Helpers: `studio_optimistic_*`, `optimistic_read/templates`, `content_compliance/optimistic_queue.dart`.
32. WCAG token pairs: keep `studio_token_contrast_test.dart` green when changing `StudioTokens`.
33. Page routes: `studio_page_transitions.dart` — fade + project studio push; wired in `product_shell/router.dart`.
34. Tooltips: prefer `StudioTooltip` over raw `Tooltip` for token chrome.
35. Batch transfer UI: `StudioTransferProgress` / `StudioTransferProgressList`.
36. l10n: keys `feature.surface.element.state`; parity via `scripts/check_arb_locale_parity.py` (see `docs/plans/flutter-ui-ux-l10n-conventions.md`).
37. Three-column shell: desktop `≥960dp` uses [`product_shell/product_shell_three_column_layout.dart`](../product_shell/product_shell_three_column_layout.dart) + [`studio_sidebar.dart`](../product_shell/studio_sidebar.dart); do not scale PC layout on handset.
38. Render lock: wrap product shell with [`ix/studio_render_lock_scope.dart`](ix/studio_render_lock_scope.dart); use `studioRunWithRenderLock` for local export / assembly.
39. Block assets: use [`rust_api/assets/block_urls.dart`](../rust_api/assets/block_urls.dart) + `studioAssetDpiTier`; never tiled `DecorationImage.repeat`.
40. Workspace scope: set [`rust_api/workspace_scope.dart`](../rust_api/workspace_scope.dart) on workspace switch; pass `studioAuthorizedHeaders` / `X-Workspace-Id` on API calls.

## Verification

```bash
bash scripts/studio-visual-debt-check.sh
cd frontend && flutter analyze
cd frontend && flutter test test/ui/studio_async_sections_test.dart
```

E2E UI audit: `bash scripts/run-ui-ux-audit-e2e.sh` (see [`docs/plans/ui-e2e-runbook.md`](../../../docs/plans/ui-e2e-runbook.md)).
