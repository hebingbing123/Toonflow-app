# Studio async loading / empty / error

Use these components for **data-fetch surfaces** (lists, panels, dialogs, settings blocks). Do not use full-page `CircularProgressIndicator` or raw red `Text` for API failures.

## Loading

| Surface | Component |
|---------|-----------|
| Full pane / section | `StudioLoadingPane` or `StudioPaneLoadingSkeleton` |
| List / table | `StudioListSkeleton` |
| Card grid | `StudioGridSkeleton` |
| Detail / form column | `StudioPaneLoadingSkeleton(density: StudioPaneLoadingDensity.detail)` |
| Media tile | `StudioMediaTileSkeleton` |
| Button / toolbar in-flight | `CircularProgressIndicator(strokeWidth: 2)` in the button slot only |

## Empty

- No data after success: `StudioEmptyState` / `StudioEmptyState.emptyData` / `StudioEmptyState.firstUse`.

## Error

| Scope | Component |
|-------|-----------|
| Full pane (blocks content) | `StudioEmptyState.loadFailed(context, error:, onRetry:)` |
| Inline / section / list item | `StudioApiErrorCallout` (`emphasis: subtle` in dense UI) |
| Pane with `StudioLoadState` | `StudioAsyncDataView` + `resolveStudioPaneLoadState(reported:, busy:, hasData:)` |

Reference implementations (`StudioAsyncDataView`): main shell sections (`task_center`, `jobs`, `quality_reviews`, `notifications`, `team_workspaces`, `platform_status`, `account`, `api_keys`, `content_compliance`, `admin_console` detail, Help Hub panels, `platform_config`, `status_page`, `global_search` results/history); settings (`plan_usage`, `model_pricing_catalog_view`, `spend_summary_panel`, `model_vendors_section`, `subscribe_plan_page`); projects (`section` grid load, `agent_memory_view`); project editor (`project_members_panel`, `project_audit_panel`, `step_model_routing_section`, asset images workbench sections); project studio (`project_studio_scope`, `script_step_panel`, `art_step_panel`, `studio_video_step_panel`, `studio_review_pack_scope`, `studio_step_model_routing_bar`, `novel_inline_import_section`); storyboard (`storyboard_studio_page`, `storyboard_shot_intake_panel`); script editor `workbench_view`; short video (`export_history_dialog`, `export_progress_dialog`, `assembly_input_panel`, `version_manager`, `view_publish_drafts`, `section_production_assembly`, batch TTS dialog); `quality_reviews/previews` + `support_stats`; `design_system/studio_model_cost_controls`; `product_studio_route_launcher`, `product_studio_overlay`.

**Intentionally not wrapped** (local/inline UX): `global_search_bar` palette suggestions, button `CircularProgressIndicator(strokeWidth: 2)`, pagination load-more, agent card action spinners, `StudioSkeleton` height-4 inline rows, preview-byte loading in asset workbench.

Format errors with `describeUserVisibleApiErrorResolved(context, e)` — never `e.toString()` in UI.

## Keep as-is

- `LinearProgressIndicator(value: …)` for real progress (export, upload, WebView).
- Form/auth validation (e.g. login).
- Semantic status banners (gate/blocking counts), not API load failures.
- Snackbars for **action** success/failure toasts (still use localized error text, not raw exceptions).
