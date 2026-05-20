# UI end-to-end runbook

Full-stack UI E2E exercises **Supabase Auth**, the **Rust API** (`8666`), and **Flutter integration tests** on a **macOS desktop** device. This is distinct from PR gate `scripts/run-ui-review-gates.sh` (widget/golden only, no backend).

## Prerequisites

| Requirement | Notes |
|-------------|--------|
| macOS + Xcode | Flutter `-d macos` desktop target |
| Docker | Supabase CLI local stack |
| [Supabase CLI](https://supabase.com/docs/guides/cli) | `supabase` on `PATH` |
| Rust toolchain | `cargo` in `backend/` |
| Flutter stable | `flutter doctor` green for macOS |
| Ports free | API **8666**; Supabase **64321** / **64322** (see `supabase/config.toml`) |

Optional: copy `env/.env.dev` values — the runner loads them via `scripts/local_test_env.sh` and `supabase status -o env`.

Dev admin (seeded): `admin@openflow.local` / `admin123` — see `scripts/seed_local_dev_admin.sh`.

## Commands

```bash
# First run (starts Supabase if needed, db reset, backend, integration test)
bash scripts/run-ui-e2e.sh

# Compact shell gallery (~7 PNGs, ~3–5 min with warm stack)
bash scripts/run-ui-e2e.sh --gallery

# Full surface gallery (30+ PNGs, ~8–15 min with warm stack)
OPENFLOW_UI_E2E_SKIP_RESET=1 bash scripts/run-ui-e2e.sh --full-gallery

# Iteration: skip db reset, reuse running Supabase
bash scripts/run-ui-e2e-local.sh

# Backend already running
OPENFLOW_UI_E2E_SKIP_BACKEND=1 bash scripts/run-ui-e2e-local.sh --full-gallery
```

Logs: `OPENFLOW_UI_E2E_LOG_DIR=/tmp/my-e2e bash scripts/run-ui-e2e.sh`

**Full gallery output:** `frontend/build/e2e_gallery/regular_XX_<scenario_id>.png` (cleared at start of each `--full-gallery` run).

## Tests

| Script flag | Integration test | What it covers |
|-------------|------------------|----------------|
| default `--smoke` | `integration_test/real_product_shell_auth_smoke_test.dart` | `StudioProductApp`, Supabase login, shell chrome |
| `--gallery` | `integration_test/real_product_shell_auth_gallery_test.dart` | Smoke paths + 7 PNGs (notifications, settings, tasks, compliance) |
| `--full-gallery` | `integration_test/real_product_shell_full_gallery_test.dart` | ≥30 PNGs: utility panes, settings tabs, pipeline/more menu, create-project wizard, project studio steps |

Dart defines: `frontend/dart_defines.dev.json` (`API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`).

### Full gallery shot list (expected)

| # | File suffix | scenario_id |
|---|-------------|-------------|
| 01 | `login_default` | Product login |
| 02 | `projects_default` | Projects home + pipeline strip |
| 03 | `notifications_studio` | Notifications utility pane |
| 04–07 | `settings_*` | Settings hub tabs (account, plan, API, workspaces) |
| 08 | `help_hub_webhooks` | Help hub |
| 09 | `more_menu` | «更多» sheet |
| 10–19 | tasks, quality, jobs, short video, team/API/compliance/status/config, script/production panes | Secondary panes via «更多» |
| 20–22 | `create_project_wizard_*` | Create-project wizard steps (no persist) |
| 23 | `projects_with_seed_project` | Grid after creating one project |
| 24–26 | `studio_step_script`, `studio_step_art`, `storyboard_studio_step` | Project studio (live API) |
| 26 | `product_shell_chrome` | Return to shell home |

**Runtime (typical):** smoke ~2–4 min; compact gallery ~4–8 min; full gallery ~8–15 min (cold stack + `db reset` adds several minutes).

### E2E gap audit (inventory vs real-stack PNG)

See [`docs/product/ux/ui-surface-inventory.md`](../product/ux/ui-surface-inventory.md) column `e2e_full_gallery`. Summary:

| scenario_id | E2E full gallery | Reach in real app |
|-------------|------------------|-------------------|
| login_default | yes | cold start |
| projects_default / product_shell_chrome | yes | post-login `/` |
| notifications_studio | yes | app bar 通知 |
| settings_account / plan / api / workspaces | yes | 账户与设置 → tabs |
| help_hub_webhooks | yes | app bar 帮助 |
| tasks / quality / jobs / short_video / team / api_keys / compliance / platform_* | yes | «更多» menu (`scrollUntilVisible`) |
| script_workspace / production_workspace | yes | «更多» (may show select-project hint without scope) |
| create_project (wizard) | yes | 新建项目 |
| studio_step_script / studio_step_art / storyboard_studio_step | yes | open grid project → studio steps |
| benchmark_default | **no** | no entry in 4-icon studio shell (harness chips only) |
| episode_console | **no** | needs script numeric id + `/projects/:id/console/:scriptId` |
| storyboard_studio (full page overlay) | **no** | route exists; no shell menu entry without in-project CTA |
| export_* / confirmation dialogs | **no** | widget tests + short-video assembly context |
| quality_stale / empty / api_error | **no** | injected controller states (widget goldens) |
| cmd_palette_open / conflict_banner | **no** | widget/smoke tests only |
| search_empty | **no** | needs search query + results route |
| pipeline_tasks autoload | partial | tasks pane screenshot; deep autoload not asserted |

## CI

Manual / nightly only (macOS + Docker): [`.github/workflows/ui-e2e.yml`](../../.github/workflows/ui-e2e.yml) via **workflow_dispatch**. PR job `ui-smoke` (Ubuntu) is unchanged.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `supabase db reset` exits 1 after migrations (Colima) | `bash scripts/supabase_db_reset_local.sh`; if Auth still 502/500: `supabase stop --no-backup`, remove stale `supabase_*_openflow-app` containers, `supabase start --ignore-health-check`, wait until `docker inspect supabase_db_openflow-app` is **healthy**, then reset again |
| `db reset` leaves Auth stopped | Runner calls `ensure_supabase_ready` to `supabase start` full stack after reset |
| Storage unhealthy | `supabase start --ignore-health-check` (runner does this) |
| Wrong Supabase port in Flutter | Runner passes `--dart-define=SUPABASE_URL` from `supabase status -o env` (project uses **64421** in `supabase/config.toml`, not 54321) |
| No macOS device | `flutter devices`; enable macOS desktop in Flutter |
| Backend `/api/v1/ready` timeout | Check `$LOG_DIR/backend.log`; ensure `DATABASE_URL` from `supabase status` |
| Login fails / seed HTTP 500 | GoTrue cannot scan NULL `confirmation_token` on SQL-seeded users — fixed in `supabase/seed.sql`; runner also runs `fix_auth_seed_null_tokens`. If Auth still broken: `supabase stop --no-backup`, `supabase start --ignore-health-check`, reset again |
| Full gallery &lt; 30 PNGs | Check `$LOG_DIR/flutter-integration.log`; ensure feature panes enabled in platform config (jobs/quality toggles) |

Backend-only E2E (no Flutter): `bash scripts/run_e2e_regression_tests.sh`.
