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

# Full shell navigation + PNG gallery (heavier)
bash scripts/run-ui-e2e.sh --gallery

# Iteration: skip db reset, reuse running Supabase
bash scripts/run-ui-e2e-local.sh

# Backend already running
OPENFLOW_UI_E2E_SKIP_BACKEND=1 bash scripts/run-ui-e2e-local.sh
```

Logs: `OPENFLOW_UI_E2E_LOG_DIR=/tmp/my-e2e bash scripts/run-ui-e2e.sh`

## Tests

| Script flag | Integration test | What it covers |
|-------------|------------------|----------------|
| default `--smoke` | `integration_test/real_product_shell_auth_smoke_test.dart` | `StudioProductApp`, Supabase login, shell chrome |
| `--gallery` | `integration_test/real_product_shell_auth_gallery_test.dart` | Smoke + notifications/settings/tasks/compliance + PNG shots |

Dart defines: `frontend/dart_defines.dev.json` (`API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`).

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

Backend-only E2E (no Flutter): `bash scripts/run_e2e_regression_tests.sh`.
