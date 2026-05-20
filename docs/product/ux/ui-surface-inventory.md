# UI Surface Inventory

> 真源：自动化测试绑定表。禁止 `manual`；不可自动化标 `automation_blocked` + 原因。  
> 关联：[UI review 报告](ui-review-2026-05-18.md)（机器生成）、[studio-ix-covenant](studio-ix-covenant.md)

| scenario_id | surface | test_kind | test_path | golden_path | e2e_full_gallery | wave | done |
|-------------|---------|-----------|-----------|-------------|------------------|------|------|
| login_default | ProductLoginPage | widget + integration_golden | test/ui/desktop_layout_widget_gallery_test.dart | test/goldens/desktop_layouts/01_login.png | yes | 1 | done |
| login_error | ProductLoginPage error | widget | test/ui/login_page_test.dart | — | no | 1 | done |
| projects_default | ProjectsSection | widget + integration_golden | test/ui/desktop_layout_widget_gallery_test.dart | test/goldens/desktop_layouts/03_projects.png | yes | 1 | done |
| projects_empty | ProjectsStudioHome empty | widget + golden | test/ui/ui_gallery_wave1_golden_test.dart | test/goldens/ui_gallery/projects_empty.png | no | 1 | done |
| tasks_default | TaskCenterSection | widget + integration_golden | test/ui/desktop_layout_widget_gallery_test.dart | test/goldens/desktop_layouts/04_task_center.png | yes | 1 | done |
| tasks_empty | TaskCenterSection studio empty | widget + golden | test/ui/ui_gallery_wave1_golden_test.dart | test/goldens/ui_gallery/tasks_empty.png | no | 1 | done |
| tasks_api_error | TaskCenterSection error | widget | test/ui/task_center_api_error_test.dart | — | no | 1 | done |
| quality_default | QualityReviewsSection | widget + golden | test/ui/quality_reviews_section_test.dart, desktop_layout_widget_gallery_test.dart | test/goldens/desktop_layouts/05_quality.png | yes | 1 | done |
| quality_stale | Quality freshness stale | widget + integration_golden | test/ui/quality_freshness_banner_test.dart | test/goldens/ui_gallery/quality_stale.png | no | 1 | done |
| quality_empty | Quality dashboard not loaded | widget + golden | test/ui/ui_gallery_wave1_golden_test.dart | test/goldens/ui_gallery/quality_empty.png | no | 1 | done |
| quality_api_error | Quality dashboard load fail | widget | test/ui/quality_freshness_banner_test.dart | — | no | 1 | done |
| jobs_default | JobsSection studio | widget + golden | test/ui/jobs_section_studio_test.dart, desktop_layout_widget_gallery_test.dart | test/goldens/desktop_layouts/11_jobs.png | yes | 1 | done |
| notifications_studio | NotificationsSection studio | widget + golden | test/ui/notifications_section_studio_test.dart | test/goldens/ui_gallery/notifications_studio.png | yes | 2 | done |
| notifications_utility | Notifications utility pane (shell route) | widget | test/ui/notifications_utility_studio_test.dart | — | yes | 2 | done |
| team_workspaces_logged_out | TeamWorkspacesSection (no token) | widget | test/ui/team_workspaces_studio_test.dart | — | no | 2 | done |
| settings_account | SettingsHub tab 0 | widget + golden | test/ui/settings_hub_studio_test.dart, desktop_layout_widget_gallery_test.dart | test/goldens/desktop_layouts/06_settings_account.png | yes | 2 | done |
| settings_plan_usage | SettingsHub plan tab | widget + golden | test/ui/desktop_layout_widget_gallery_test.dart | test/goldens/desktop_layouts/06a_settings_plan_usage.png | yes | 2 | done |
| short_video_overview | ShortVideoSpaceView overview | widget + golden | test/ui/short_video_overview_test.dart | test/goldens/ui_gallery/short_video_overview.png | yes | 2 | done |
| studio_step_script | ProjectStudio script | widget + golden | test/ui/studio_step_script_test.dart | test/goldens/ui_gallery/studio_step_script.png | yes | 2 | done |
| studio_step_art | ProjectStudio art direction | widget + golden | test/ui/studio_step_art_test.dart, test/project_studio/project_studio_art_scope_test.dart | test/goldens/ui_gallery/studio_step_art.png | yes | 2 | done |
| studio_load_error | ProjectStudioScope error | widget | test/ui/project_studio_scope_test.dart | — | no | 2 | done |
| storyboard_studio | StoryboardStudioPage | widget + golden | test/storyboard_studio/storyboard_studio_page_test.dart | test/goldens/ui_gallery/storyboard_studio.png | partial | 2 | done |
| episode_console | EpisodeConsolePage | widget + golden | test/episode_console/episode_console_page_test.dart | test/goldens/ui_gallery/episode_console.png | no | 2 | done |
| search_empty | Search no-results illustration | widget + golden | test/ui/search_no_results_test.dart | test/goldens/ui_gallery/search_empty.png | no | 2 | done |
| cmd_palette_open | StudioCommandPaletteShortcuts | smoke | integration_test/studio_interaction_smoke_test.dart | — | no | 1 | done |
| conflict_banner | StudioConflictBanner | smoke | integration_test/studio_interaction_smoke_test.dart | — | no | 1 | done |
| pipeline_tasks | Product pane tasks + URI sync | widget | test/ui/pipeline_tasks_autoload_test.dart | — | partial | 1 | done |
| api_error_callout | StudioApiErrorCallout | widget + golden | test/ui/ui_gallery_wave1_golden_test.dart | test/goldens/ui_gallery/api_error_callout.png | no | 1 | done |
| job_tray_active | StudioJobTray | widget + smoke | test/ui/studio_job_tray_test.dart | — | no | 1 | done |
| product_shell_chrome | App bar + pipeline strip | widget + golden | test/ui/desktop_layout_widget_gallery_test.dart | test/goldens/desktop_layouts/02_product_shell_chrome.png | yes | 1 | done |
| help_hub_webhooks | Help Hub (debug seeds) | widget + golden | test/ui/help_hub_studio_test.dart | test/goldens/desktop_layouts/10_help_hub.png | yes | 2 | done |
| settings_api | SettingsHub API tab | widget + golden | test/ui/desktop_layout_widget_gallery_test.dart | test/goldens/desktop_layouts/07_settings_api.png | yes | 2 | done |
| settings_workspaces | SettingsHub workspaces tab | widget + golden | test/ui/desktop_layout_widget_gallery_test.dart | test/goldens/desktop_layouts/08_settings_workspaces.png | yes | 2 | done |
| benchmark_default | BenchmarkSection | widget + golden | test/ui/desktop_layout_widget_gallery_test.dart | test/goldens/desktop_layouts/12_benchmark.png | no | 2 | done |
| platform_config | Platform config pane | widget + golden | test/ui/platform_config_desktop_golden_test.dart | test/goldens/desktop_layouts/13_platform_config.png | yes | 2 | done |
| content_compliance_queue | ContentComplianceSection | widget + golden | test/content_compliance_section_test.dart, desktop_layout_widget_gallery_test.dart | test/goldens/desktop_layouts/09_content_compliance.png | yes | 2 | done |
| platform_status | PlatformStatusSection | widget + golden | test/ui/platform_status_studio_test.dart, platform_status_desktop_golden_test.dart | test/goldens/desktop_layouts/14_platform_status.png | yes | 2 | done |
| utility_routes | notifications/help/settings-models/platform-status | widget | test/product_shell/router_utility_integration_test.dart | — | partial | 1 | done |
| product_shell_e2e_smoke | StudioProductApp login + shell | e2e | integration_test/real_product_shell_auth_smoke_test.dart | — | smoke | 1 | done |
| product_shell_e2e_gallery | StudioProductApp compact nav + PNG | e2e | integration_test/real_product_shell_auth_gallery_test.dart | — | compact | 1 | done |
| product_shell_e2e_full_gallery | StudioProductApp full nav + PNG | e2e | integration_test/real_product_shell_full_gallery_test.dart | build/e2e_gallery/ | full | 1 | done |

## Top dialogs (Phase 7)

| dialog_id | file | test_path | done |
|-----------|------|-----------|------|
| create_project | create_project_wizard.dart | test/dialogs/create_project_wizard_test.dart | done |
| export_progress | export_progress_dialog.dart | test/dialogs/export_progress_dialog_test.dart (incl. ExportProgressDialog) | done |
| export_settings | export_settings_dialog.dart | test/dialogs/export_settings_dialog_test.dart | done |
| voiceover_settings | voiceover_settings_dialog.dart | test/dialogs/voiceover_settings_dialog_test.dart | done |
| delete_version_confirm | confirmation_dialogs.dart | test/dialogs/confirmation_delete_version_test.dart | done |
| cancel_export_confirm | confirmation_dialogs.dart | test/dialogs/cancel_export_confirmation_test.dart | done |
| batch_disable_confirm | confirmation_dialogs.dart | test/dialogs/confirmation_batch_disable_test.dart | done |
| restore_draft_confirm | confirmation_dialogs.dart | test/dialogs/confirmation_restore_draft_test.dart | done |
| export_history | export_history_dialog.dart | test/dialogs/export_history_dialog_test.dart (+ test/export_history_dialog_test.dart) | done |

## CI gates

| Job | When | Command |
|-----|------|---------|
| `ui-smoke` | Every PR | `scripts/run-ui-review-gates.sh` (widget + golden + export_history + utility routes; macOS smoke optional) |
| `ui-golden` | Schedule / manual | `flutter test test/ui/ --name golden` + `integration_test/desktop_layout_gallery_test.dart` (device) |
| `ui-e2e` | Manual (`workflow_dispatch`) | `scripts/run-ui-e2e.sh` — Supabase + Rust :8666 + Flutter integration on macOS ([runbook](../../plans/ui-e2e-runbook.md)); full PNGs: `--full-gallery` → `frontend/build/e2e_gallery/` |

## Feature-gated panes

| pane | inventory_id | widget golden |
|------|--------------|---------------|
| `benchmark` | `benchmark_default` | `12_benchmark.png` |
| `jobs` | `jobs_default` | `11_jobs.png` |
| `platformConfig` | `platform_config` | `13_platform_config.png` |
| `platformStatus` | `platform_status` | `14_platform_status.png` |

Integration-only layouts (device): `integration_test/desktop_layout_gallery_test.dart` → `build/desktop_layouts/` (full gallery).

| scenario_id | reason |
|-------------|--------|
| help_hub_billing_scroll | `10a_help_hub_laptop_billing` — long-scroll billing audit; covered by `help_hub_studio_test` webhook seeds + integration gallery |
| pipeline_tasks_autoload | `_ensureProductPaneData(tasks)` hits live Rust HTTP; widget tests hang or time out without `HttpOverrides`/mock. Pane wiring covered by `pipeline_tasks_autoload_test.dart`; full autoload needs backend mock or macOS integration smoke with API |
| studio_interaction_smoke_ci | `integration_test/studio_interaction_smoke_test.dart` requires `-d macos`; PR `ui-smoke` on Ubuntu skips it (report: `skipped`). Runs locally/scheduled on macOS runners |
| desktop_layout_integration_gallery | `integration_test/desktop_layout_gallery_test.dart` writes `build/desktop_layouts/` on device; scheduled `ui-golden` job uses widget goldens under `test/goldens/desktop_layouts/` instead |
| product_shell_e2e_ci | Full-stack E2E needs Docker + macOS runner + ~10–15 min; not on every PR — use `workflow_dispatch` job `ui-e2e` or local `scripts/run-ui-e2e.sh` |
