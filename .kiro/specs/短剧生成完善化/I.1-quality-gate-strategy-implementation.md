# I.1 Quality Gate Strategy Implementation

**Date**: 2025-01-11  
**Task**: I.1 Upgrade export quality gate to off/warn/block strategy  
**Status**: ✅ Completed

## Executive Summary

Successfully upgraded the quality gate enforcement system from a binary block/allow model to a three-strategy system (off/warn/block), providing flexible quality control for different project needs and development stages.

### Key Changes

1. **New Strategy Enum**: Created `QualityGateStrategy` with three modes:
   - **off**: Skip all quality gate checks
   - **warn**: Show warnings but allow operations to proceed
   - **block**: Block operations if quality issues detected (default)

2. **Database Schema**: Added `quality_gate_strategy` column to `app_project` table

3. **API Updates**: Extended project PATCH endpoint to support quality gate strategy configuration

4. **Enforcement Logic**: Updated quality gate enforcement to respect the configured strategy

## Implementation Details

### 1. Strategy Module (`backend/src/production/quality_gate/strategy.rs`)

Created a new module defining the `QualityGateStrategy` enum:

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, ToSchema, Default)]
#[serde(rename_all = "snake_case")]
pub enum QualityGateStrategy {
    Off,
    Warn,
    #[default]
    Block,
}
```

**Features**:
- Default strategy is `Block` (maintains backward compatibility)
- String parsing from "off", "warn", "block"
- Helper methods: `should_skip_checks()`, `should_block()`, `should_warn()`
- Full test coverage

### 2. Database Migration (`supabase/migrations/20260411000000_add_quality_gate_strategy.sql`)

```sql
ALTER TABLE public.app_project
ADD COLUMN IF NOT EXISTS quality_gate_strategy TEXT;

ALTER TABLE public.app_project
ADD CONSTRAINT quality_gate_strategy_check
CHECK (quality_gate_strategy IS NULL OR quality_gate_strategy IN ('off', 'warn', 'block'));
```

**Features**:
- Nullable column (defaults to NULL, which is interpreted as "block")
- Check constraint ensures only valid values
- Documentation comment added

### 3. Enforcement Logic Updates (`backend/src/production/quality_gate/enforce.rs`)

**`run_quality_gate` function**:
- Now returns `(QualityGateDecision, QualityGateStrategy)` tuple
- Loads strategy from project configuration
- Skips all checks if strategy is "off"
- Logs debug message when checks are skipped

**`enforce_quality_gate` function**:
- Accepts `strategy` parameter
- Implements three-strategy enforcement:
  - **off**: Always allows (returns Ok)
  - **warn**: Logs warning but allows (returns Ok)
  - **block**: Blocks on severe issues (returns Err)

**`load_quality_gate_strategy` helper**:
- Queries `app_project.quality_gate_strategy`
- Parses string to enum
- Defaults to `Block` if NULL or missing

### 4. Integration Points Updated

Updated all three quality gate call sites:

1. **`backend/src/harness/sub_agent/mod.rs`** (StoryboardPanel stage)
2. **`backend/src/production/workbench/meta/generate/mod.rs`** (VideoPrompt stage)
3. **`backend/src/production/workbench/video/generate/mod.rs`** (VideoGenerate stage)

All now use the pattern:
```rust
let (gate, strategy) = run_quality_gate(...).await?;
enforce_quality_gate(stage, &gate, strategy)?;
```

### 5. API Updates

**ProjectRow** (`backend/src/projects/routes/types.rs`):
- Added `quality_gate_strategy: Option<String>` field

**PatchProjectBody** (`backend/src/projects/routes/types.rs`):
- Added `quality_gate_strategy: Option<Value>` field

**Patch Handler** (`backend/src/projects/routes/handlers/detail/patch.rs`):
- Added validation for quality_gate_strategy
- Included in UPDATE query
- Included in SELECT queries

**Validation** (`backend/src/projects/routes/validation.rs`):
- Added `validate_quality_gate_strategy()` function
- Test coverage for valid/invalid values

### 6. Test Updates

**Unit Tests**:
- `enforce_quality_gate_blocks_severe_decision` - Tests block strategy
- `enforce_quality_gate_allows_with_warn_strategy` - Tests warn strategy
- `enforce_quality_gate_allows_with_off_strategy` - Tests off strategy
- `test_validate_quality_gate_strategy` - Tests validation logic

**Property Tests**:
- Updated `prop_high_cost_stage_precheck_blocks_on_severe_issues` to test all three strategies
- Verifies correct behavior for each strategy with various issue severities

## Behavior Matrix

| Strategy | Severe Issues | Minor Issues | Behavior |
|----------|---------------|--------------|----------|
| **off** | Any | Any | ✅ Allow (skip checks) |
| **warn** | Present | Any | ⚠️ Log warning, allow |
| **warn** | None | Present | ⚠️ Log warning, allow |
| **block** | Present | Any | ❌ Block with error |
| **block** | None | Present | ✅ Allow |
| **block** | None | None | ✅ Allow |

## Usage Examples

### Setting Quality Gate Strategy via API

```bash
# Disable quality gate for development
PATCH /api/v1/projects/{project_id}
{
  "qualityGateStrategy": "off"
}

# Enable warnings only (for testing)
PATCH /api/v1/projects/{project_id}
{
  "qualityGateStrategy": "warn"
}

# Enable blocking (production default)
PATCH /api/v1/projects/{project_id}
{
  "qualityGateStrategy": "block"
}

# Reset to default (block)
PATCH /api/v1/projects/{project_id}
{
  "qualityGateStrategy": null
}
```

### Logging Behavior

**Off Strategy**:
```
DEBUG quality gate checks skipped (strategy=off) project_id=123 stage=video_prompt
```

**Warn Strategy**:
```
WARN quality gate issues detected (warn mode - allowing operation to proceed) 
     stage=video_prompt blocked=true severe_count=2 minor_count=1
```

**Block Strategy**:
```
ERROR quality precheck blocked video_prompt: 先删掉互相冲突的镜头/灯光/动作指令，再继续生成。
```

## Use Cases

### Development/Testing (off)
- Rapid iteration without quality checks
- Testing generation pipeline without interruption
- Debugging quality gate logic itself

### Staging/QA (warn)
- Collect quality metrics without blocking
- Identify quality issues for later review
- Gradual rollout of new quality rules

### Production (block)
- Enforce quality standards before expensive operations
- Prevent low-quality content from reaching users
- Maintain consistent output quality

## Backward Compatibility

✅ **Fully backward compatible**:
- Existing projects without `quality_gate_strategy` field default to "block"
- NULL values are interpreted as "block"
- No changes required to existing code or data

## Performance Impact

**Minimal**:
- Single additional DB query per quality gate check (loads strategy)
- Query is simple and indexed (owner_user_id + numeric_id)
- "off" strategy skips all quality checks (performance improvement)

## Future Enhancements

### Potential Improvements (Not Implemented)

1. **Per-Stage Strategy**:
   - Different strategies for StoryboardPanel, VideoPrompt, VideoGenerate
   - Example: `{ "storyboard_panel": "warn", "video_generate": "block" }`

2. **Severity-Based Strategy**:
   - Block on severe, warn on minor
   - Example: `{ "severe": "block", "minor": "warn" }`

3. **Time-Based Strategy**:
   - Automatic strategy changes based on time/date
   - Example: "warn" during business hours, "block" overnight

4. **User-Level Override**:
   - Allow users to override project strategy temporarily
   - Requires additional permission checks

5. **Strategy Audit Log**:
   - Track when strategy changes
   - Track when warnings were ignored

## Files Modified

### New Files
- `backend/src/production/quality_gate/strategy.rs` - Strategy enum and logic
- `supabase/migrations/20260411000000_add_quality_gate_strategy.sql` - DB migration
- `.kiro/specs/短剧生成完善化/I.1-quality-gate-strategy-implementation.md` - This document

### Modified Files
- `backend/src/production/quality_gate/mod.rs` - Export strategy, update tests
- `backend/src/production/quality_gate/enforce.rs` - Load and enforce strategy
- `backend/src/production/mod.rs` - Export QualityGateStrategy
- `backend/src/harness/sub_agent/mod.rs` - Use new signature
- `backend/src/production/workbench/meta/generate/mod.rs` - Use new signature
- `backend/src/production/workbench/video/generate/mod.rs` - Use new signature
- `backend/src/projects/routes/types.rs` - Add quality_gate_strategy fields
- `backend/src/projects/routes/handlers/detail/patch.rs` - Support PATCH
- `backend/src/projects/routes/validation.rs` - Add validation

## Testing

### Automated Tests
✅ All tests passing:
- Unit tests for strategy enum
- Unit tests for enforcement logic
- Property tests for all strategies
- Validation tests
- Integration tests (via refactor-check.sh)

### Manual Testing Checklist

- [ ] Create project with strategy="off", verify no quality checks
- [ ] Create project with strategy="warn", verify warnings logged
- [ ] Create project with strategy="block", verify blocking works
- [ ] PATCH project to change strategy, verify it takes effect
- [ ] Test with NULL strategy, verify defaults to "block"
- [ ] Test with invalid strategy, verify validation error
- [ ] Test all three quality gate stages (StoryboardPanel, VideoPrompt, VideoGenerate)

## Deployment Notes

1. **Migration**: Run `20260411000000_add_quality_gate_strategy.sql` migration
2. **Backward Compatibility**: No data migration needed (NULL defaults to "block")
3. **Rollback**: Safe to rollback - column is nullable and has default behavior
4. **Monitoring**: Watch for increased "warn" strategy usage in logs

## Conclusion

The quality gate strategy system provides flexible quality control while maintaining backward compatibility and performance. The three-strategy model (off/warn/block) covers common use cases from development to production, with clear semantics and comprehensive test coverage.

**Next Steps**:
- I.2: Add quality gate validation before publish queue
- I.3: Extend quality comparison to storyboard+video+output
- I.4: Promote quality nextAction to typed field for rework action
- I.5: Connect low-performance alert to rewrite/republish loop

