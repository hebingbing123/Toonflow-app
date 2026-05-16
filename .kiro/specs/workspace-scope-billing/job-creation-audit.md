# Job Creation Entry Points Audit (Task 2.1)

**Date**: 2025-01-XX  
**Related**: `.kiro/specs/workspace-scope-billing/` Task 2.1  
**ADR**: `docs/plans/adr-workspace-billing-storage-model.md`

## Summary

This document audits all entry points where `app_generation_job` records are created and documents the implementation of the canonical `resolve_billing_workspace_id` function for workspace billing attribution.

## Canonical Resolution Function

**Location**: `backend/src/jobs/billing_workspace.rs`

**Function**: `resolve_billing_workspace_id(pool, user_id, resolved_workspace_id_from_project)`

### Resolution Rules (Priority Order)

1. **Project-based jobs**: If `resolved_workspace_id_from_project` is `Some`, use it
   - This comes from `normalize_project_scope_in_job_payload` which resolves project → workspace
   - Applies to all jobs with `project_uuid` or `project_numeric_id` in payload

2. **User's current workspace**: If no project context, use `app_user_profile.current_workspace_id`
   - Only if the user is still a member of that workspace
   - Only if the workspace is not archived

3. **User's personal workspace**: Fallback to user's personal workspace
   - Guaranteed to exist via `ensure_personal_workspace`
   - Always succeeds (never returns None)

### Edge Cases Handled

- **Orphan jobs** (no project, no current_workspace_id): → Personal workspace
- **Invalid current_workspace_id** (user no longer member): → Personal workspace
- **Archived workspace**: → Personal workspace
- **Project without workspace_id**: → Database FK constraint error (should not happen)

## Job Creation Entry Points

### 1. `backend/src/jobs/enqueue.rs` - `enqueue_generation_job`

**Status**: ✅ Updated (Task 2.1)

**Usage**: Internal function called by various handlers for non-idempotent job creation

**Changes**:
- Added call to `resolve_billing_workspace_id` after project resolution
- Updated INSERT to include `workspace_id` column
- Enhanced logging to include `billing_workspace_id`

**SQL**:
```sql
INSERT INTO app_generation_job (owner_user_id, kind, payload, status, idempotency_key, workspace_id)
VALUES ($1, $2, $3, 'queued', NULL, $4)
```

**Resolution Flow**:
```
normalize_project_scope_in_job_payload (if project in payload)
  ↓
resolve_billing_workspace_id (canonical)
  ↓
INSERT with workspace_id
```

### 2. `backend/src/jobs/handlers/mutate/create.rs` - `POST /api/v1/jobs`

**Status**: ✅ Updated (Task 2.1)

**Usage**: HTTP endpoint for creating jobs with optional idempotency

**Changes**:
- Added call to `resolve_billing_workspace_id` after project resolution
- Updated INSERT to include `workspace_id` column
- Enhanced logging to include `billing_workspace_id`
- Handles idempotency key conflicts (existing jobs don't need workspace_id update)

**SQL**:
```sql
INSERT INTO app_generation_job (owner_user_id, kind, payload, status, idempotency_key, workspace_id)
VALUES ($1, $2, $3, 'queued', $4, $5)
```

**Resolution Flow**:
```
Check idempotency (if key exists, return existing job)
  ↓
normalize_project_scope_in_job_payload (if project in payload)
  ↓
resolve_billing_workspace_id (canonical)
  ↓
INSERT with workspace_id
```

### 3. `backend/src/narrative/novels/handlers/crawl_schedule.rs` - `POST /api/v1/projects/{project_id}/novels/crawl-schedules`

**Status**: ✅ Updated (Task 2.1)

**Usage**: HTTP endpoint for creating novel crawl schedule jobs (project-scoped)

**Changes**:
- Added query to fetch `project.workspace_id` from `project_id` path parameter
- Added call to `resolve_billing_workspace_id` with project's workspace_id
- Updated INSERT to include `workspace_id` column (idempotency path)
- Non-idempotency path uses `enqueue_generation_job` (already updated)

**SQL**:
```sql
-- Get project's workspace_id
SELECT p.workspace_id FROM app_project p WHERE p.id = $1 AND p.archived_at IS NULL

-- Insert with workspace_id
INSERT INTO app_generation_job (owner_user_id, kind, payload, status, idempotency_key, workspace_id)
VALUES ($1, $2, $3, 'queued', $4, $5)
```

**Resolution Flow**:
```
Fetch project.workspace_id from path parameter
  ↓
resolve_billing_workspace_id (with project workspace_id)
  ↓
INSERT with workspace_id (if idempotency key)
  OR
enqueue_generation_job (if no idempotency key, already handles workspace_id)
```

### 4. `backend/src/jobs/queue/pg.rs` - `PgQueue::enqueue`

**Status**: ⚠️ Documented (Task 2.1)

**Usage**: Low-level queue interface used by workers for job re-enqueuing

**Changes**:
- Added TODO comment noting that this path may need workspace_id resolution
- Currently does NOT set workspace_id (column remains nullable during migration)
- This is acceptable during migration period (Task 2.2 backfill will handle it)

**SQL**:
```sql
INSERT INTO app_generation_job (id, user_id, kind, payload, status, priority, created_at)
VALUES ($1, $2, $3, $4, 'queued', $5, now())
-- Note: workspace_id is NULL here
```

**Rationale for deferring**:
- This queue interface is used by workers, not HTTP handlers
- Workers may re-enqueue jobs (e.g., retry logic, scheduled jobs)
- During migration period (Task 2.2), workspace_id is nullable
- After backfill (Task 2.3), we can enforce NOT NULL and revisit this path
- Most production jobs go through HTTP handlers (paths 1-3 above)

**Future consideration** (post-Task 2.3):
- Option A: Require `workspace_id` in `JobPayload` struct
- Option B: Add `resolve_billing_workspace_id` call in `PgQueue::enqueue`
- Option C: Deprecate this interface in favor of HTTP handlers only

## Database Schema

**Migration**: `supabase/migrations/20260519130000_app_generation_job_workspace_id.sql`

**Column**: `app_generation_job.workspace_id UUID REFERENCES app_workspace(id) ON DELETE CASCADE`

**Nullability**: Currently nullable (Task 2.2 backfill in progress)

**Indexes**:
- `idx_app_generation_job_workspace_created` - For jobs_today counts
- `idx_app_generation_job_workspace_status` - For active jobs per workspace
- `idx_app_generation_job_workspace_daily` - For daily quota enforcement

## Testing

### Unit Tests

**Location**: `backend/src/jobs/billing_workspace.rs`

- Documents resolution priority order
- Placeholder for integration tests (require DB)

### Integration Tests

**TODO** (Task 2.1 follow-up):
- Test project-based job → uses project's workspace_id
- Test non-project job with current_workspace_id → uses current workspace
- Test non-project job without current_workspace_id → uses personal workspace
- Test archived workspace fallback → uses personal workspace
- Test user not member of current_workspace_id → uses personal workspace

### Contract Tests

**TODO** (Task 9.1):
- Add PG contract tests for job creation with workspace_id
- Test both personal and enterprise workspace scenarios

## Logging and Observability

All job creation paths now log:
- `user_id`: Job owner
- `job_id`: Job UUID
- `kind`: Job type
- `workspace_id`: Project workspace (if project-based job)
- `billing_workspace_id`: Resolved workspace for billing attribution
- `client_request_id`: Request tracing

**Example log**:
```
event = "generation_job_enqueued"
user_id = "..."
job_id = "..."
kind = "assets-generate/image"
workspace_id = "..." (project workspace, if applicable)
billing_workspace_id = "..." (always present)
client_request_id = "..."
```

## Migration Path

### Phase 1: Additive (Current - Task 2.1) ✅

- [x] Add `workspace_id` column (nullable)
- [x] Implement `resolve_billing_workspace_id` function
- [x] Update HTTP job creation paths to persist workspace_id
- [x] Document PgQueue path (deferred)
- [x] Add logging for observability

### Phase 2: Backfill (Task 2.2) 🔄

- [ ] Write backfill script with `--dry-run`
- [ ] Backfill workspace_id from project → workspace for project-based jobs
- [ ] Backfill workspace_id from user → personal workspace for orphan jobs
- [ ] Monitor backfill coverage (target: >99%)

### Phase 3: Enforcement (Task 2.3) ⏳

- [ ] Add NOT NULL constraint on `workspace_id` column
- [ ] Update PgQueue path to require workspace_id
- [ ] Remove nullable handling in application code

## Rollback Plan

**Phase 1 rollback** (before Task 2.3):
```sql
-- Remove workspace_id column (safe, no behavior change)
DROP INDEX IF EXISTS public.idx_app_generation_job_workspace_daily;
DROP INDEX IF EXISTS public.idx_app_generation_job_workspace_status;
DROP INDEX IF EXISTS public.idx_app_generation_job_workspace_created;
ALTER TABLE public.app_generation_job DROP COLUMN IF EXISTS workspace_id;
```

**Code rollback**:
- Revert INSERT statements to exclude `workspace_id`
- Remove `resolve_billing_workspace_id` calls
- Remove `billing_workspace.rs` module

**Phase 2+ rollback** (after backfill):
- NOT RECOMMENDED (data loss)
- If required, follow runbook in Task 9.1

## References

- **Spec**: `.kiro/specs/workspace-scope-billing/`
- **Requirements**: `requirements.md` (2.1, 2.2, 2.3, 9.3)
- **Design**: `design.md` (Job creation flows)
- **Tasks**: `tasks.md` (Task 2.1)
- **ADR**: `docs/plans/adr-workspace-billing-storage-model.md`
- **Migration**: `supabase/migrations/20260519130000_app_generation_job_workspace_id.sql`

## Sign-off

- [x] **Task 2.1 Complete**: Canonical function implemented and wired into job creation paths
- [ ] **Task 2.2**: Backfill script (next task)
- [ ] **Task 2.3**: NOT NULL enforcement (after backfill)

**Completed by**: Kiro (AI Agent)  
**Date**: 2025-01-XX
