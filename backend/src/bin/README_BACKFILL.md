# Backfill Job Workspace ID

This directory contains the `backfill_job_workspace_id.rs` binary for backfilling `workspace_id` on existing `app_generation_job` records.

## Quick Start

```bash
# 1. Dry-run (preview changes)
cd backend
DATABASE_URL=postgresql://user:pass@host/db \
  cargo run --bin backfill-job-workspace-id -- --dry-run

# 2. Apply changes
DATABASE_URL=postgresql://user:pass@host/db \
  cargo run --bin backfill-job-workspace-id

# 3. Verify results
cd ../scripts
DATABASE_URL=postgresql://user:pass@host/db \
  ./verify_workspace_id_backfill.sh
```

## Documentation

- **Full Runbook**: `docs/runbooks/backfill-job-workspace-id.md`
- **Spec**: `.kiro/specs/workspace-scope-billing/`
- **ADR**: `docs/plans/adr-workspace-billing-storage-model.md`

## Options

- `--dry-run`: Preview changes without applying them (recommended first step)
- `--batch-size <N>`: Process N jobs per batch (default: 1000)

## Resolution Strategy

1. **Project-based jobs**: Resolve from `project_uuid` or `project_numeric_id` in payload
2. **Orphan jobs**: Fallback to user's personal workspace

## Safety Features

- ✅ Idempotent (can run multiple times)
- ✅ Transactional batches
- ✅ Progress reporting
- ✅ Error handling with detailed logging
- ✅ Dry-run mode

## Example Output

```
INFO starting workspace_id backfill dry_run=true batch_size=1000
INFO jobs with NULL workspace_id found total_jobs=5432
INFO processing batch batch_size=1000 processed=0 total=5432
INFO progress update processed=1000 updated=1000 failed=0 total=5432 progress_pct=18
...
INFO === Backfill Summary ===
INFO backfill complete mode="DRY-RUN" total_jobs=5432 processed=5432 updated=5432 failed=0
INFO Resolution methods:
INFO method stats method="project_uuid" count=4123 percentage=75
INFO method stats method="personal_workspace" count=1309 percentage=24
INFO DRY-RUN mode: no changes were applied
```

## Troubleshooting

See the full runbook at `docs/runbooks/backfill-job-workspace-id.md` for:
- Validation queries
- Failed job handling
- Performance tuning
- Rollback procedures

## Related Files

- Binary: `backend/src/bin/backfill_job_workspace_id.rs`
- Tests: `backend/tests/backfill_job_workspace_id_test.rs`
- Migration: `supabase/migrations/20260519130000_app_generation_job_workspace_id.sql`
- Job creation: `backend/src/jobs/enqueue.rs`
- Workspace resolution: `backend/src/jobs/billing_workspace.rs`
- Verification script: `scripts/verify_workspace_id_backfill.sh`
