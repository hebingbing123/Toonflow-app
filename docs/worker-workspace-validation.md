# Worker-Side Workspace Validation

## Overview

This document describes the workspace membership validation implemented in worker-side project write-back operations. All worker code that writes to project resources validates workspace membership before performing write operations, ensuring that job owners must be workspace members to write to project resources.

Unless otherwise noted, `project_id` / `script_id` in SQL snippets below refer to database foreign keys (`app_project.id`, `app_script.id` UUID). Numeric identifiers shown in validation queries are compatibility filters derived from payload scope, not a product-level numeric-first routing rule.

## Validated Write Operations

### 1. Voiceover Generation (`backend/src/jobs/worker/voiceover.rs`)

**Operation**: Update storyboard metadata with voiceover information

**Function**: `persist_storyboard_voiceover_metadata`

**SQL**:
```sql
UPDATE app_storyboard
SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{voiceover}', $2::jsonb, true),
    updated_at = NOW()
WHERE id = $1
```

**Validation**: Performed in `load_storyboard_uuid` before write:
```sql
SELECT sb.id
FROM app_storyboard sb
INNER JOIN app_script sc ON sc.id = sb.script_id
INNER JOIN app_project p ON p.id = sc.project_id
WHERE EXISTS (
        SELECT 1
        FROM app_workspace_member wm
        WHERE wm.workspace_id = p.workspace_id
          AND wm.user_id = $1
  )
  AND p.numeric_id = $2
  AND sc.numeric_id = $3
  AND sb.numeric_id = $4
```

**Additional Validation**: `load_project_voice_profile` also validates workspace membership:
```sql
SELECT voice_profile
FROM app_project
WHERE numeric_id = $2
  AND EXISTS (
        SELECT 1
        FROM app_workspace_member wm
        WHERE wm.workspace_id = app_project.workspace_id
          AND wm.user_id = $1
  )
```

### 2. Video Generation/Export (`backend/src/jobs/worker/video/storage.rs`)

**Operation**: Update storyboard with video file path

**Function**: `store_video_reference`

**SQL**:
```sql
UPDATE app_storyboard
SET file_path = $1, state = '已完成', updated_at = NOW()
FROM app_script, app_project
WHERE app_storyboard.script_id = app_script.id
  AND app_script.project_id = app_project.id
  AND EXISTS (
        SELECT 1
        FROM app_workspace_member wm
        WHERE wm.workspace_id = app_project.workspace_id
          AND wm.user_id = $2
  )
  AND app_project.numeric_id = $3
  AND app_storyboard.numeric_id = $4
```

**Validation**: Workspace membership check is embedded directly in the UPDATE statement. If the user is not a workspace member, the UPDATE will match 0 rows and the operation will be logged as a writeback failure (but the job will still succeed with error details).

### 3. Asset Image Generation (`backend/src/jobs/worker/asset_image/common/store/persist.rs`)

**Operation**: Insert new asset image record

**Function**: `generate_and_store_asset_image_for_row`

**SQL**:
```sql
INSERT INTO app_asset_image (id, asset_id, sort_index, file_path, state, metadata)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id
```

**Validation**: Performed before insert to verify asset ownership:
```sql
SELECT a.project_id
FROM app_asset a
INNER JOIN app_project p ON p.id = a.project_id
WHERE a.id = $1
  AND EXISTS (
        SELECT 1
        FROM app_workspace_member wm
        WHERE wm.workspace_id = p.workspace_id
          AND wm.user_id = $2
  )
```

If the query returns no rows, the function returns `JobRunError::Failed("asset not found for owner".into())`.

### 4. Storyboard Batch Image Generation (`backend/src/jobs/worker/asset_image/production/storyboard_batch.rs`)

**Operation**: Update storyboard with generated image URL

**Function**: `run_production_storyboard_batch_generate_image`

**SQL**:
```sql
UPDATE app_storyboard
SET file_path = $2, state = '已完成', updated_at = NOW()
WHERE id = $1
```

**Validation**: Performed before update to load storyboard ID:
```sql
SELECT sb.id
FROM app_storyboard sb
INNER JOIN app_script s ON s.id = sb.script_id
INNER JOIN app_project p ON p.id = s.project_id
WHERE EXISTS (
        SELECT 1
        FROM app_workspace_member wm
        WHERE wm.workspace_id = p.workspace_id
          AND wm.user_id = $1
  )
  AND p.numeric_id = $2
  AND s.numeric_id = $3
  AND sb.numeric_id = $4
```

If the query returns no rows, the function returns `JobRunError::Failed("storyboard not in scope".into())`.

## Non-Project Write Operations

### Asset Polish (`backend/src/jobs/worker/asset_polish.rs`)

**Operations**: `run_asset_polish_prompt`, `run_asset_polish_batch`

**Validation**: These operations do NOT write to project resources. They only:
1. Read project information using `resolve_project_numeric_from_job_payload` (which validates workspace membership)
2. Return polished prompts in the job result
3. Record LLM usage metrics

No database writes to project resources are performed, so no additional validation is needed.

### Novel Crawl Import (`backend/src/jobs/worker/novel_crawl.rs`)

**Operation**: `run_novel_crawl_import_batch`

**Validation**: Uses `require_project_write_scope` (same helper chain as HTTP mutations):
```rust
require_project_write_scope(state, row.owner_user_id, project_id)
    .await
    .map_err(|e| JobRunError::Failed(format!("project write scope check failed: {e:?}")))?;
```

This function validates that the user is a workspace member before allowing novel imports.

## Validation Pattern

All worker write-back operations follow this pattern:

1. **Extract project context** from job payload (`project_uuid` preferred, `project_numeric_id` legacy fallback, plus `script_numeric_id`, `storyboard_numeric_id`, etc.)
2. **Validate workspace membership** using one of these approaches:
   - Query with `EXISTS (SELECT 1 FROM app_workspace_member WHERE workspace_id = ... AND user_id = ...)` before write
   - Embed workspace membership check in the UPDATE/INSERT statement itself
   - Use helper functions like `require_project_write_scope` / `require_project_workspace_member_scope` or `resolve_project_numeric_from_job_payload`
3. **Perform write operation** only if validation succeeds
4. **Return error** if validation fails (either `JobRunError::Failed` or 0 rows affected)

## Security Guarantees

- **No unauthorized writes**: Workers cannot write to projects where the job owner is not a workspace member
- **Consistent with HTTP handlers**: Worker validation uses the same workspace membership checks as HTTP API endpoints
- **Defense in depth**: Even if RLS policies are bypassed (service role), application-layer validation prevents unauthorized writes
- **Audit trail**: Failed write-back operations are logged and included in job error details

## Testing

Comprehensive integration tests are provided in `backend/src/jobs/worker/workspace_validation_tests.rs`:

- `test_video_store_reference_validates_workspace_membership`
- `test_voiceover_load_storyboard_validates_workspace_membership`
- `test_asset_image_persist_validates_workspace_membership`
- `test_storyboard_batch_image_validates_workspace_membership`
- `test_voiceover_load_project_voice_profile_validates_workspace_membership`

Each test verifies that:
- Workspace owners can perform write operations
- Workspace members can perform write operations
- Non-members (outsiders) cannot perform write operations

## Related Documentation

- `docs/plans/workspace-team-full-plan.md` - Overall workspace implementation plan
- `docs/workspace-project-permission-policy.md` - Workspace permission policy
- `docs/workspace-security-boundary.md` - Security boundary between RLS and application layer
- `.kiro/specs/platform-completion-phase2/requirements.md` - Requirements for workspace validation
- `.kiro/specs/platform-completion-phase2/design.md` - Design for workspace validation

## Conclusion

All worker-side project write-back operations properly validate workspace membership before performing writes. This ensures that:

1. Job owners must be workspace members to write to project resources
2. Workers cannot bypass workspace access controls
3. The security model is consistent between HTTP handlers and worker code
4. Defense-in-depth is maintained (application layer + RLS)

Task W2.7 is complete: worker-side project write-back queries validate workspace membership.
