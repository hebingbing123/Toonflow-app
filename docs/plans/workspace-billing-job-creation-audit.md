# Job Creation Entry Points Audit (Task 2.1)

**Spec**: `.kiro/specs/workspace-scope-billing/`  
**Task**: 2.1 - Audit all job creation entry points; implement canonical `resolve_billing_workspace_id(...)`  
**Date**: 2025-01-XX  
**Status**: ✅ Complete

## Executive Summary

All job creation entry points in the Toonflow backend have been audited. The canonical `resolve_billing_workspace_id` function has been implemented and is correctly used by all active job creation paths. No additional changes are required for Task 2.1.

Note: this document belongs to the **future workspace-scope billing migration** track. Statements about persisting `workspace_id` on `app_generation_job` describe that gated migration design, not current production billing behavior.

## Canonical Function

**Location**: `backend/src/jobs/billing_workspace.rs`

```rust
pub async fn resolve_billing_workspace_id(
    pool: &PgPool,
    user_id: Uuid,
    resolved_workspace_id_from_project: Option<Uuid>,
) -> Result<Uuid, ApiError>
```

### Resolution Rules (Priority Order)

1. **Project-based jobs**: If `resolved_workspace_id_from_project` is provided (from `normalize_project_scope_in_job_payload`), use it
2. **User's current workspace**: If no project context, use user's `current_workspace_id` from `app_user_profile` (if valid and user is still a member)
3. **User's personal workspace**: Fallback to user's personal workspace (guaranteed to exist via `ensure_personal_workspace`)

### Key Properties

- **Always returns a workspace_id**: Never returns `None`
- **Validates membership**: Ensures user is still a member of current_workspace before using it
- **Handles archived workspaces**: Falls back to personal workspace if current workspace is archived
- **Thread-safe**: Uses database queries for all resolution logic

## Job Creation Entry Points

### 1. Primary Entry Point: `enqueue_generation_job`

**Location**: `backend/src/jobs/enqueue.rs`

**Status**: ✅ Correctly implements workspace_id resolution

**Usage**: Called by 15+ handlers across the codebase

**Implementation**:
```rust
// Resolve workspace_id from project context (if applicable)
let resolved_workspace_id =
    normalize_project_scope_in_job_payload(pool, owner_user_id, &mut payload).await?;

// Canonical workspace_id resolution for billing attribution
let billing_workspace_id =
    resolve_billing_workspace_id(pool, owner_user_id, resolved_workspace_id).await?;

// Persist workspace_id in app_generation_job
INSERT INTO app_generation_job (owner_user_id, kind, payload, status, idempotency_key, workspace_id)
VALUES ($1, $2, $3, 'queued', NULL, $4)
```

**Callers** (all correctly use this function):
- `backend/src/production/workbench/edit_image/generation.rs`
- `backend/src/production/workbench/storyboard_ops/batch_generate.rs`
- `backend/src/production/workbench/assets/batch_ops.rs`
- `backend/src/production/workbench/voiceover.rs`
- `backend/src/production/workbench/storyboard_media_op.rs`
- `backend/src/production/workbench/video/generate/mod.rs`
- `backend/src/assets/generate/handlers/batch_generate/generate_image_assets.rs`
- `backend/src/assets/generate/handlers/generate_one.rs`
- `backend/src/assets/generate/handlers/polish.rs`
- `backend/src/assets/generate/handlers/batch_generate/polish_prompt.rs`
- `backend/src/jobs/worker/novel_crawl.rs` (worker-initiated recurring jobs)
- `backend/src/harness/invoke/domain_production/generate.rs`
- `backend/src/narrative/novels/handlers/crawl_schedule.rs` (fallback path)
- `backend/src/projects/routes/tts.rs`
- `backend/src/settings/vendors/handlers/model_test.rs`
- `backend/src/settings/account/handlers.rs`

### 2. HTTP Endpoint: `POST /api/v1/jobs`

**Location**: `backend/src/jobs/handlers/mutate/create.rs`

**Status**: ✅ Correctly implements workspace_id resolution

**Implementation**:
```rust
// Resolve workspace_id from project context (if applicable)
let resolved_workspace_id =
    normalize_project_scope_in_job_payload(pool, uid, &mut payload).await?;

// Canonical workspace_id resolution for billing attribution (Task 2.1)
let billing_workspace_id =
    resolve_billing_workspace_id(pool, uid, resolved_workspace_id).await?;

// Persist workspace_id in app_generation_job
INSERT INTO app_generation_job (owner_user_id, kind, payload, status, idempotency_key, workspace_id)
VALUES ($1, $2, $3, 'queued', $4, $5)
```

**Features**:
- HTTP idempotency via `X-Idempotency-Key` header
- Quota check with billing context
- Client request ID tracking

### 3. Novel Crawl Schedule (Direct INSERT with idempotency)

**Location**: `backend/src/narrative/novels/handlers/crawl_schedule.rs`

**Status**: ✅ Correctly implements workspace_id resolution

**Implementation**:
```rust
// Resolve workspace_id for billing attribution (Task 2.1)
// Get the project's workspace_id for project-based jobs
let project_workspace_id: Uuid = sqlx::query_scalar(
    r#"
    SELECT p.workspace_id
    FROM app_project p
    WHERE p.id = $1
      AND p.archived_at IS NULL
    "#,
)
.bind(project_id)
.fetch_one(pool)
.await?;

let billing_workspace_id =
    resolve_billing_workspace_id(pool, uid, Some(project_workspace_id)).await?;

// Direct INSERT with idempotency
INSERT INTO app_generation_job (owner_user_id, kind, payload, status, idempotency_key, workspace_id)
VALUES ($1, $2, $3, 'queued', $4, $5)
```

**Rationale for direct INSERT**: This endpoint needs custom idempotency logic for scheduled/recurring jobs, so it uses a direct INSERT instead of `enqueue_generation_job`, but still uses the canonical `resolve_billing_workspace_id`.

### 4. Legacy Queue Interface (INACTIVE)

**Location**: `backend/src/jobs/queue/pg.rs`

**Status**: ⚠️ Contains old INSERT without workspace_id, but **NOT USED**

**Analysis**:
- The `PgQueue::enqueue` method has an old INSERT statement that doesn't include `workspace_id`
- **Grep search confirms**: No code calls `.enqueue()` anywhere in the codebase
- Only used for: `PgQueue::stats()` (read-only queue statistics)
- **Action**: Added TODO comment in code for future cleanup, but no immediate risk

**Recommendation**: Consider removing the unused `enqueue` method or updating it to match current patterns in a future cleanup task.

## Verification

### All Active Paths Use Canonical Function ✅

Every active job creation path:
1. Calls `normalize_project_scope_in_job_payload` (if project context exists)
2. Calls `resolve_billing_workspace_id` with the result
3. Persists the resolved `workspace_id` in `app_generation_job.workspace_id`

### Logging and Observability ✅

All job creation paths log:
- `user_id`: The user creating the job
- `job_id`: The generated job UUID
- `kind`: The job type
- `workspace_id`: The project/context workspace (if applicable)
- `billing_workspace_id`: The resolved billing workspace
- `client_request_id`: Request tracking ID

Example log:
```rust
tracing::info!(
    event = "generation_job_enqueued",
    user_id = %owner_user_id,
    job_id = %row.id,
    kind = %row.kind,
    workspace_id = %workspace_id,
    billing_workspace_id = %billing_workspace_id,
    client_request_id = client_request_id_from_payload(&row.payload).unwrap_or(""),
    "generation job enqueued"
);
```

### Quota Integration ✅

All job creation paths check quota with billing context:
```rust
quota::check_daily_job_quota_with_context(
    pool,
    owner_user_id,
    billing_workspace_id,
    billing_config,
).await?;
```

This ensures quota enforcement aligns with billing attribution (Requirement 4).

## Edge Cases Handled

### 1. Jobs Without Project Context ✅
- **Example**: Settings export, vendor model test
- **Resolution**: Uses user's `current_workspace_id` or personal workspace
- **Code**: `resolve_billing_workspace_id(pool, user_id, None)`

### 2. Worker-Initiated Jobs ✅
- **Example**: Novel crawl recurring jobs (worker re-enqueues next run)
- **Resolution**: Uses `enqueue_generation_job` which resolves workspace_id
- **Code**: `backend/src/jobs/worker/novel_crawl.rs`

### 3. Archived Workspaces ✅
- **Handling**: `resolve_billing_workspace_id` validates workspace is not archived
- **Fallback**: Uses personal workspace if current workspace is archived

### 4. Invalid current_workspace_id ✅
- **Handling**: Query validates user is still a member of current workspace
- **Fallback**: Uses personal workspace if membership check fails

### 5. Personal Workspaces ✅
- **Handling**: Personal workspace is guaranteed to exist via `ensure_personal_workspace`
- **Behavior**: Same structural fields as enterprise workspaces (Requirement 1.3)

## Testing Coverage

### Unit Tests
- `backend/src/jobs/billing_workspace.rs`: Documents resolution priority order

### Integration Tests (Task 9.1)

Covered by `backend/src/app/pg_contract_tests/business_suite/job_workspace_attribution_roundtrip.rs`.

- [x] Project-based job → uses project's workspace_id
- [x] Non-project job with current_workspace_id → uses current workspace
- [x] Non-project job without current_workspace_id → uses personal workspace
- [x] Archived current workspace → falls back to personal workspace
- [x] Invalid current_workspace_id → falls back to personal workspace

## Related Tasks

- **Task 2.2**: Backfill script for existing jobs without workspace_id
- **Task 2.3**: Enforce NOT NULL constraint after backfill
- **Task 3.2**: Implement workspace `jobs_today` aggregate
- **Task 3.3**: Wire quota checks to use effective billing context
- **Task 9.1**: Add PG contract tests for workspace billing scenarios

## Conclusion

✅ **Task 2.1 is COMPLETE**

All job creation entry points have been audited and correctly implement the canonical `resolve_billing_workspace_id` function. The implementation:

1. ✅ Resolves workspace_id for all new jobs
2. ✅ Persists workspace_id in `app_generation_job.workspace_id`
3. ✅ Handles all edge cases (no project, archived workspace, invalid current workspace)
4. ✅ Integrates with quota enforcement
5. ✅ Provides comprehensive logging for debugging
6. ✅ Supports both personal and enterprise workspaces

No code changes are required for Task 2.1. The canonical function is implemented and in use.

## Appendix: File Locations

### Core Implementation
- `backend/src/jobs/billing_workspace.rs` - Canonical resolution function
- `backend/src/jobs/enqueue.rs` - Primary job creation function
- `backend/src/jobs/payload_project.rs` - Project workspace resolution helper

### Job Creation Handlers (all use canonical function)
- `backend/src/jobs/handlers/mutate/create.rs` - HTTP endpoint
- `backend/src/narrative/novels/handlers/crawl_schedule.rs` - Novel crawl schedules
- 15+ other handlers via `enqueue_generation_job`

### Supporting Modules
- `backend/src/workspaces/mod.rs` - `ensure_personal_workspace`
- `backend/src/metering/quota.rs` - Quota enforcement with billing context
