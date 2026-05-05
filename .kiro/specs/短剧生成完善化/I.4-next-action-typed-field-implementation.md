# I.4 Promote Quality NextAction to Typed Field for Rework Action

**Date**: 2025-01-12  
**Task**: I.4 Promote quality nextAction to typed field for rework action  
**Status**: ✅ Completed

## Executive Summary

Successfully promoted the quality review "nextAction" from a free-text field in model_params to a structured, typed database field. This enables programmatic processing of quality feedback to trigger appropriate rework workflows (e.g., "regenerate_storyboard", "adjust_video_prompt", "retry_video_generation").

### Key Changes

1. **Database Schema**: Added `next_action` column to `app_quality_review` table with enum constraint
2. **NextAction Enum Extension**: Added 4 new action types for video generation workflows
3. **API Updates**: Extended quality review creation to store and filter by next_action
4. **Backward Compatibility**: Maintains existing free-text actions in model_params while adding typed field

## Implementation Details

### 1. Database Migration (`supabase/migrations/20260412000000_add_next_action_to_quality_review.sql`)

Added `next_action` column with check constraint:

```sql
ALTER TABLE public.app_quality_review
ADD COLUMN IF NOT EXISTS next_action TEXT;

ALTER TABLE public.app_quality_review
ADD CONSTRAINT next_action_check
CHECK (next_action IS NULL OR next_action IN (
    'patch_storyboard_items',
    'rollback_to_director_planning',
    'update_character_anchor',
    'observe',
    'regenerate_storyboard',
    'adjust_video_prompt',
    'retry_video_generation',
    'manual_review'
));

CREATE INDEX idx_quality_review_next_action ON public.app_quality_review(next_action) 
WHERE next_action IS NOT NULL;
```

**Features**:
- Nullable column (defaults to NULL)
- Check constraint ensures only valid values
- Index for efficient filtering
- Documentation comment added

### 2. NextAction Enum Extension (`backend/src/prompting/quality/next_action.rs`)

Extended the enum with 4 new action types:

```rust
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "text")]
#[serde(rename_all = "snake_case")]
pub enum NextAction {
    /// 定点修复若干分镜条目（局部返工）
    PatchStoryboardItems,
    /// 回退到导演规划阶段重做
    RollbackToDirectorPlanning,
    /// 更新角色锚点后重生成
    UpdateCharacterAnchor,
    /// 继续观察，暂不干预
    Observe,
    /// 重新生成分镜 (NEW)
    RegenerateStoryboard,
    /// 调整视频提示词 (NEW)
    AdjustVideoPrompt,
    /// 重试视频生成 (NEW)
    RetryVideoGeneration,
    /// 需要人工审核 (NEW)
    ManualReview,
}

impl FromStr for NextAction {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "patch_storyboard_items" => Ok(Self::PatchStoryboardItems),
            "rollback_to_director_planning" => Ok(Self::RollbackToDirectorPlanning),
            "update_character_anchor" => Ok(Self::UpdateCharacterAnchor),
            "observe" => Ok(Self::Observe),
            "regenerate_storyboard" => Ok(Self::RegenerateStoryboard),
            "adjust_video_prompt" => Ok(Self::AdjustVideoPrompt),
            "retry_video_generation" => Ok(Self::RetryVideoGeneration),
            "manual_review" => Ok(Self::ManualReview),
            _ => Err(format!("Invalid next_action value: {}", s)),
        }
    }
}
```

**Features**:
- Implements `FromStr` trait for standard parsing
- Implements `sqlx::Type` for database serialization
- Implements `Serialize`/`Deserialize` for JSON API
- All 8 action types supported

### 3. Type Updates (`backend/src/prompting/quality/types.rs`)

**QualityReview**:
```rust
pub struct QualityReview {
    // ... existing fields ...
    /// 下一步修复动作（需求 I.4）：typed field for rework action
    pub next_action: Option<String>,
}
```

**CreateQualityReviewBody**:
```rust
pub struct CreateQualityReviewBody {
    // ... existing fields ...
    /// 下一步修复动作（需求 I.4）
    pub next_action: Option<String>,
}
```

**ListQualityReviewsQuery**:
```rust
pub struct ListQualityReviewsQuery {
    // ... existing fields ...
    /// 按下一步动作过滤（需求 I.4）
    pub next_action: Option<String>,
}
```

### 4. Handler Updates

**Create Handler** (`backend/src/prompting/quality/handlers/create.rs`):

Updated to store next_action in two places:
1. **Database field**: Stores the typed action directly
2. **model_params.diagnostics**: Maintains backward compatibility

```rust
// Store next_action in database
let next_action_str = body.next_action.as_deref();
let mut review = sqlx::query_as::<_, QualityReview>(
    r#"
    INSERT INTO app_quality_review (
        ..., next_action
    ) VALUES (..., $27)
    RETURNING *
    "#,
)
// ... bindings ...
.bind(next_action_str)
.fetch_one(pool)
.await?;

// Infer next_action if not provided
let issue_types = infer_issue_types(&review);
let next_action = infer_next_action(&review, &issue_types);

// Update both model_params and next_action field
let next_action_to_store = if review.next_action.is_none() {
    Some(next_action.as_str())
} else {
    review.next_action.as_deref()
};

review = sqlx::query_as::<_, QualityReview>(
    r#"UPDATE app_quality_review 
       SET model_params = $2, next_action = $3, updated_at = NOW() 
       WHERE id = $1 
       RETURNING *"#,
)
.bind(review.id)
.bind(merged_model_params)
.bind(next_action_to_store)
.fetch_one(pool)
.await?;
```

**List Handler** (`backend/src/prompting/quality/handlers/list.rs`):

Added filtering by next_action:

```rust
if let Some(next_action) = &query.next_action {
    qb.push(" AND next_action = ");
    qb.push_bind(next_action);
}
```

### 5. Test Coverage

Created comprehensive unit tests (`backend/src/prompting/quality/next_action_tests.rs`):

- **test_next_action_as_str**: Verifies string representation
- **test_next_action_from_str**: Tests FromStr parsing
- **test_infer_next_action_grade_d_triggers_rollback**: Tests inference logic
- **test_infer_next_action_severe_score_triggers_rollback**: Tests severe score handling
- **test_infer_next_action_character_consistency_triggers_update_anchor**: Tests character issues
- **test_infer_next_action_bad_case_triggers_patch**: Tests bad case handling
- **test_infer_next_action_low_score_triggers_patch**: Tests low score handling
- **test_infer_next_action_failed_triggers_patch**: Tests failed review handling
- **test_infer_next_action_good_review_triggers_observe**: Tests passing review
- **test_next_action_serialization**: Tests JSON serialization
- **test_next_action_deserialization**: Tests JSON deserialization

All tests pass ✅

## Action Type Mapping

| Action Type | Use Case | Trigger Condition |
|-------------|----------|-------------------|
| **patch_storyboard_items** | Fix specific storyboard entries | Bad case, low score (< 6), or failed review |
| **rollback_to_director_planning** | Restart from planning stage | Grade D or severe score (< 4) |
| **update_character_anchor** | Update character reference | Character consistency issues |
| **observe** | No action needed | Good quality (score ≥ 6, passed) |
| **regenerate_storyboard** | Regenerate entire storyboard | Storyboard-level quality issues |
| **adjust_video_prompt** | Modify video generation prompt | Video prompt quality issues |
| **retry_video_generation** | Retry video generation | Video generation failures |
| **manual_review** | Requires human review | Complex or ambiguous issues |

## API Usage Examples

### Creating Quality Review with Next Action

```bash
POST /api/v1/quality/reviews
{
  "projectId": 123,
  "scriptId": 456,
  "targetType": "storyboard",
  "targetId": "789",
  "overallScore": 4,
  "passed": false,
  "isBadCase": true,
  "nextAction": "patch_storyboard_items"
}
```

### Filtering by Next Action

```bash
GET /api/v1/quality/reviews?nextAction=regenerate_storyboard
```

### Auto-Inference

If `nextAction` is not provided, it will be automatically inferred:

```bash
POST /api/v1/quality/reviews
{
  "projectId": 123,
  "scriptId": 456,
  "targetType": "storyboard",
  "targetId": "789",
  "overallScore": 3,
  "grade": "D"
}
# → next_action will be inferred as "rollback_to_director_planning"
```

## Backward Compatibility

✅ **Fully backward compatible**:
- Existing quality reviews without `next_action` field continue to work (NULL values)
- `model_params.diagnostics.nextAction` is still populated for legacy consumers
- New field is optional in API requests
- Auto-inference ensures next_action is always set

## Integration with Rework Workflows

The typed `next_action` field enables:

1. **Programmatic Routing**: Rework systems can query by action type
2. **Workflow Automation**: Trigger specific rework pipelines based on action
3. **Metrics & Analytics**: Track which actions are most common
4. **Priority Queuing**: Route high-priority actions (e.g., rollback) first

### Example Rework Query

```sql
-- Find all storyboards needing regeneration
SELECT DISTINCT target_id::int AS storyboard_id
FROM app_quality_review
WHERE user_id = $1
  AND project_id = $2
  AND target_type = 'storyboard'
  AND next_action = 'regenerate_storyboard'
  AND created_at > NOW() - INTERVAL '7 days'
ORDER BY storyboard_id;
```

## Future Enhancements

### Potential Improvements (Not Implemented)

1. **Action Priority Levels**:
   - Add priority field (high/medium/low)
   - Route high-priority actions first
   - Example: rollback = high, observe = low

2. **Action Execution Tracking**:
   - Track when action was executed
   - Track execution result (success/failure)
   - Link to rework job_id

3. **Action Chaining**:
   - Define action sequences (e.g., adjust_prompt → retry_generation)
   - Track progress through action chain
   - Auto-advance to next action on success

4. **Action Recommendations**:
   - ML model to suggest best action
   - Learn from historical success rates
   - Personalize by user/project

5. **Action Audit Trail**:
   - Track who triggered action
   - Track when action was completed
   - Track quality improvement after action

## Files Modified

### New Files
- `supabase/migrations/20260412000000_add_next_action_to_quality_review.sql` - Database migration
- `backend/src/prompting/quality/next_action_tests.rs` - Unit tests
- `.kiro/specs/短剧生成完善化/I.4-next-action-typed-field-implementation.md` - This document

### Modified Files
- `backend/src/prompting/quality/next_action.rs` - Extended enum, added FromStr
- `backend/src/prompting/quality/types.rs` - Added next_action fields
- `backend/src/prompting/quality/handlers/create.rs` - Store next_action in DB
- `backend/src/prompting/quality/handlers/list.rs` - Filter by next_action
- `backend/src/prompting/quality/mod.rs` - Added test module
- `backend/src/prompting/benchmark/judge/handlers.rs` - Added next_action field
- `backend/src/prompting/benchmark/judge/scorer.rs` - Added next_action field
- `backend/src/prompting/quality/feedback.rs` - Added next_action field
- `backend/src/prompting/quality/tests.rs` - Added next_action field
- `backend/src/metering/llm_usage.rs` - Added next_action field

## Testing

### Automated Tests
✅ All tests passing:
- Unit tests for NextAction enum (as_str, from_str, serialization)
- Unit tests for inference logic (all trigger conditions)
- Integration tests via refactor-check.sh
- Property tests for quality review isolation

### Manual Testing Checklist

- [ ] Create quality review with explicit next_action, verify stored correctly
- [ ] Create quality review without next_action, verify auto-inference works
- [ ] Filter quality reviews by next_action, verify results
- [ ] Test all 8 action types can be stored and retrieved
- [ ] Test invalid action type is rejected by database constraint
- [ ] Verify model_params.diagnostics.nextAction is still populated
- [ ] Test backward compatibility with existing reviews (NULL next_action)

## Deployment Notes

1. **Migration**: Run `20260412000000_add_next_action_to_quality_review.sql` migration
2. **Backward Compatibility**: No data migration needed (NULL is valid)
3. **Rollback**: Safe to rollback - column is nullable
4. **Monitoring**: Watch for constraint violations (invalid action types)

## Conclusion

The typed `next_action` field provides a structured foundation for automated rework workflows. By promoting this from free-text to a typed enum, we enable programmatic processing, filtering, and routing of quality feedback to appropriate rework systems.

**Next Steps**:
- I.5: Connect low-performance alert to rewrite/republish loop
- Implement rework workflow consumers that query by next_action
- Add action execution tracking and audit trail

