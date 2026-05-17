# I.2 Quality Gate Validation Before Publish Queue

**Date**: 2025-01-11  
**Task**: I.2 Add quality gate validation before publish queue  
**Status**: ✅ Completed

## Executive Summary

Successfully integrated quality gate validation into the publish workflow. Before a publish job is queued, the system now runs quality gate checks on the associated script's storyboards, respecting the project's quality_gate_strategy setting (off/warn/block).

### Key Changes

1. **Publish Handler Integration**: Modified `create_publish_job` handler to run quality gate validation before queueing
2. **Quality Gate Stage**: Uses `QualityGateStage::VideoGenerate` (appropriate for publish, which occurs after video generation)
3. **Strategy Enforcement**: Respects project's quality_gate_strategy setting
4. **Error Handling**: Returns 409 Conflict when quality gate blocks with clear error messages

## Implementation Details

### 1. Handler Modification (`backend/src/publish/handlers.rs`)

Updated `create_publish_job` handler to:

1. Fetch the draft and verify it exists
2. If draft has an associated script_id:
   - Convert script UUID to numeric ID
   - Convert project UUID to numeric ID
   - Fetch all storyboard IDs for the script
   - Run quality gate check at VideoGenerate stage
   - Enforce quality gate based on strategy
3. Only queue the publish job if quality gate passes (or strategy allows)

**Code Flow**:
```rust
pub(crate) async fn create_publish_job(...) -> Result<...> {
    // ... auth and validation ...
    
    let draft = fetch_draft(pool, project_id, draft_id).await?
        .ok_or(ApiError::NotFound)?;

    // Run quality gate validation if draft has script
    if let Some(script_id_uuid) = draft.script_id {
        // Convert UUIDs to numeric IDs
        let script_numeric_id = /* query */;
        let project_numeric_id = /* query */;
        
        // Get storyboard IDs
        let storyboard_ids: Vec<i32> = /* query */;
        
        // Run quality gate
        let (gate, strategy) = run_quality_gate(
            pool, uid, project_numeric_id, script_numeric_id,
            QualityGateStage::VideoGenerate,
            &storyboard_ids,
            &[], // No additional text inputs
        ).await?;
        
        // Enforce based on strategy
        enforce_quality_gate(QualityGateStage::VideoGenerate, &gate, strategy)?;
    }

    // Queue the job
    let row = insert_publish_job(pool, project_id, draft_id, uid, &body).await?;
    Ok(Json(job_from_row(row)))
}
```

### 2. Module Exports (`backend/src/production/mod.rs`)

Added conditional exports for test types:
```rust
#[cfg(test)]
pub(crate) use quality_gate::{QualityGateDecision, QualityGateIssue, QualityGateSeverity};
```

### 3. Test Coverage (`backend/src/publish/quality_gate_tests.rs`)

Created comprehensive unit tests:

- **test_publish_quality_gate_blocks_severe_issues_with_block_strategy**: Verifies blocking behavior
- **test_publish_quality_gate_allows_with_warn_strategy**: Verifies warn-only behavior
- **test_publish_quality_gate_allows_with_off_strategy**: Verifies skip behavior
- **test_publish_quality_gate_allows_minor_issues_with_block_strategy**: Verifies minor issues don't block
- **test_publish_quality_gate_allows_no_issues**: Verifies clean pass

### 4. OpenAPI Documentation

Updated OpenAPI spec for `create_publish_job`:
```yaml
responses:
  200:
    description: Created
    body: PublishJobResponse
  404:
    description: Not found
  409:
    description: Quality gate blocked  # NEW
```

## Behavior Matrix

| Strategy | Draft Has Script | Quality Issues | Behavior |
|----------|------------------|----------------|----------|
| **off** | Yes | Any | ✅ Queue job (skip checks) |
| **warn** | Yes | Severe | ⚠️ Log warning, queue job |
| **warn** | Yes | Minor | ⚠️ Log warning, queue job |
| **block** | Yes | Severe | ❌ Return 409 Conflict |
| **block** | Yes | Minor | ✅ Queue job |
| **block** | Yes | None | ✅ Queue job |
| Any | No | N/A | ✅ Queue job (no script to check) |

## Quality Gate Checks at Publish Stage

The quality gate runs the following checks:

1. **Character Availability**: Ensures project has role assets or character anchors
2. **Structured Field Validation**: Validates storyboard video_desc fields
3. **Visual Conflicts**: Detects conflicting shot/lighting/action instructions
4. **Monotone Delivery Risk**: Flags dialogue without emotion/action details
5. **Pacing Issues**: Detects flat pacing without rhythm changes
6. **Gaze Direction Errors**: Catches conflicting eye direction instructions
7. **Storyboard Progression**: Evaluates emotion/performance progression across shots
8. **Quality Review Comments**: Incorporates recent quality review feedback

## Error Messages

When quality gate blocks (strategy=block), the API returns:

```json
{
  "status": 409,
  "error": "Conflict",
  "message": "quality precheck blocked video_generate: 先删掉互相冲突的镜头/灯光/动作指令，再继续生成。"
}
```

The message includes:
- Stage name (`video_generate`)
- Specific suggestion from the most severe issue

## Use Cases

### Development/Testing (off)
```bash
# Set strategy to off
PATCH /api/v1/projects/{project_id}
{ "qualityGateStrategy": "off" }

# Publish jobs queue without quality checks
POST /api/v1/projects/{project_id}/publish/drafts/{draft_id}/jobs
# → Always succeeds (unless other validation fails)
```

### Staging/QA (warn)
```bash
# Set strategy to warn
PATCH /api/v1/projects/{project_id}
{ "qualityGateStrategy": "warn" }

# Publish jobs queue with warnings logged
POST /api/v1/projects/{project_id}/publish/drafts/{draft_id}/jobs
# → Succeeds, logs: "WARN quality gate issues detected (warn mode - allowing operation to proceed)"
```

### Production (block)
```bash
# Set strategy to block (default)
PATCH /api/v1/projects/{project_id}
{ "qualityGateStrategy": "block" }

# Publish jobs blocked if quality issues detected
POST /api/v1/projects/{project_id}/publish/drafts/{draft_id}/jobs
# → Returns 409 if severe issues found
```

## Integration Points

### Upstream Dependencies
- **Task I.1**: Quality gate strategy system (off/warn/block)
- **Quality Gate Module**: `run_quality_gate` and `enforce_quality_gate` functions
- **Project Settings**: `quality_gate_strategy` field in `app_project` table

### Downstream Impact
- **Publish Worker**: Jobs in queue have already passed quality gate (if strategy=block)
- **Quality Metrics**: Quality gate decisions are persisted as agent memory
- **User Experience**: Clear error messages guide users to fix quality issues before publishing

## Performance Considerations

**Additional Queries per Publish Job Creation**:
1. Load quality_gate_strategy (1 query, indexed)
2. Convert script UUID to numeric ID (1 query, indexed)
3. Convert project UUID to numeric ID (1 query, indexed)
4. Fetch storyboard IDs (1 query, indexed)
5. Quality gate checks (multiple queries, see quality_gate module)

**Optimization**:
- Strategy "off" skips all quality checks (fastest path)
- Queries use indexed columns (owner_user_id, numeric_id, id)
- Quality gate results are cached in agent memory

**Estimated Overhead**:
- Strategy "off": ~10ms (2 queries)
- Strategy "warn/block": ~100-200ms (full quality gate)

## Testing

### Automated Tests
✅ All tests passing:
- Unit tests for all three strategies
- Unit tests for minor vs severe issues
- Unit tests for no issues case
- Integration via refactor-check.sh

### Manual Testing Checklist

发布入队前的 **`enforce_quality_gate`** 策略矩阵已由单测覆盖（`backend/src/publish/quality_gate_tests.rs`）：

- [x] strategy="block" + severe issues → 拒绝（Conflict，含 stage 名）
- [x] strategy="warn" + severe issues → 允许入队
- [x] strategy="off" → 跳过检查
- [x] minor issues + block → 允许

项目级 **`quality_gate_strategy`** PATCH/校验见 I.1 契约测 `project_quality_gate_strategy_patch_contract`。

下列由 **PG 契约测** `publish_quality_gate_job_contract` 覆盖（`backend/src/app/pg_contract_tests/publish_quality_gate_job_roundtrip.rs`；`./scripts/run_publish_quality_gate_job_contract_test.sh`）：

- [x] Create draft with script_id, set strategy="off", verify job queues without checks
- [x] Create draft with script_id, set strategy="warn", verify job queues with warnings（日志 warn 在服务端；入队 200）
- [x] Create draft with script_id, set strategy="block", verify job blocked if quality issues（无角色/分镜 → 409 + `video_generate`）
- [x] Create draft without script_id, verify job queues (no quality checks)
- [x] Verify error message includes stage name and suggestion — `test_publish_quality_gate_conflict_includes_each_stage_label`（三阶段 stage 名）
- [x] Test with NULL strategy, verify defaults to "block"（见 I.1 / `short_video_export_check`）
- [x] Test with invalid strategy, verify validation error（见 I.1 契约测）

## Backward Compatibility

✅ **Fully backward compatible**:
- Drafts without script_id skip quality gate (no change in behavior)
- Existing projects without quality_gate_strategy default to "block"
- NULL strategy is interpreted as "block"
- No database migration required

## Future Enhancements

### Potential Improvements (Not Implemented)

1. **Draft-Level Quality Cache**:
   - Cache quality gate results on draft
   - Skip re-checking if draft hasn't changed
   - Example: `draft.quality_gate_result` JSON field

2. **Publish-Specific Quality Rules**:
   - Additional checks specific to publish (e.g., video asset exists, cover image present)
   - Platform-specific quality requirements
   - Example: TikTok requires vertical video, YouTube prefers 16:9

3. **Quality Gate History**:
   - Track when quality gate blocked/warned
   - Audit trail for quality decisions
   - Example: `app_quality_gate_audit` table

4. **Batch Publish Validation**:
   - Validate multiple drafts before batch scheduling
   - Return quality status for each draft
   - Example: `POST /api/v1/projects/{project_id}/publish/drafts/batch-validate`

5. **Quality Gate Bypass**:
   - Allow users to override quality gate with reason
   - Requires additional permission check
   - Example: `{ "bypassQualityGate": true, "bypassReason": "urgent hotfix" }`

## Files Modified

### Modified Files
- `backend/src/publish/handlers.rs` - Added quality gate validation to create_publish_job
- `backend/src/publish/mod.rs` - Added quality_gate_tests module
- `backend/src/production/mod.rs` - Exported test types conditionally

### New Files
- `backend/src/publish/quality_gate_tests.rs` - Unit tests for publish quality gate integration
- `.kiro/specs/短剧生成完善化/I.2-quality-gate-publish-validation.md` - This document

## Deployment Notes

1. **No Migration Required**: Uses existing quality_gate_strategy field from I.1
2. **Backward Compatible**: Drafts without script_id skip quality checks
3. **Rollback Safe**: Can rollback without data migration
4. **Monitoring**: Watch for increased 409 responses (quality gate blocking)

## Conclusion

Quality gate validation is now integrated into the publish workflow, preventing low-quality content from being queued for publishing. The three-strategy model (off/warn/block) provides flexibility for different environments while maintaining quality standards in production.

**Next Steps**:
- I.3: Extend quality comparison to storyboard+video+output
- I.4: Promote quality nextAction to typed field for rework action
- I.5: Connect low-performance alert to rewrite/republish loop
