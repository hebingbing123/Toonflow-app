# I.3 Extend Quality Comparison to Storyboard+Video+Output

**Date**: 2025-01-12  
**Task**: I.3 Extend quality comparison to storyboard+video+output  
**Status**: ✅ Completed

## Executive Summary

Extending the quality tracking system to enable comprehensive quality comparison across the full content generation pipeline: storyboard → video → output. This allows detection of quality degradation at each stage and provides visibility into where quality issues are introduced.

### Key Goals

1. **Cross-Stage Quality Comparison**: Compare quality metrics between storyboard, video, and output stages
2. **Quality Degradation Detection**: Identify when quality drops between stages
3. **Stage-to-Stage Tracking**: Link quality reviews across the pipeline for the same content
4. **Quality Progression Visibility**: Show quality evolution through the pipeline

## Current State Analysis

### Existing Quality Infrastructure

**Quality Review Table** (`app_quality_review`):
- ✅ Has `target_type` field: 'storyboard', 'video', 'output'
- ✅ Has `stage` field: tracks generation stage
- ✅ Has quality metrics: plot_coherence, character_consistency, dialogue_naturalness, pacing, faithfulness, visual_quality, overall_score
- ✅ Has `target_id` field: links to specific storyboard/video/output

**Quality Gate System**:
- ✅ Runs at three stages: StoryboardPanel, VideoPrompt, VideoGenerate
- ✅ Detects quality issues before expensive operations
- ✅ Respects quality_gate_strategy (off/warn/block)

**Quality Aggregation**:
- ✅ Groups bad cases by stage
- ✅ Counts reviews per target_type
- ✅ Tracks late-stage bad cases (storyboard_panel, video_prompt)

### What's Missing for I.3

1. **Cross-Stage Comparison Queries**: No queries that compare quality between stages for the same content
2. **Quality Degradation Detection**: No logic to detect when quality drops between stages
3. **Stage Progression Tracking**: No explicit linking of quality reviews across stages
4. **Quality Delta Metrics**: No metrics showing quality change between stages

## Implementation Design

### 1. Quality Comparison Data Structure

Add new types to track quality across stages:

```rust
/// Quality comparison across pipeline stages for a single storyboard
pub struct StoryboardQualityProgression {
    pub storyboard_id: i32,
    pub storyboard_quality: Option<QualityMetrics>,
    pub video_quality: Option<QualityMetrics>,
    pub output_quality: Option<QualityMetrics>,
    pub quality_degradation_detected: bool,
    pub degradation_stages: Vec<String>,
}

/// Quality metrics snapshot at a specific stage
pub struct QualityMetrics {
    pub stage: String,
    pub target_type: String,
    pub overall_score: Option<i16>,
    pub passed: Option<bool>,
    pub is_bad_case: bool,
    pub review_count: i64,
    pub latest_review_id: Uuid,
    pub latest_review_at: chrono::DateTime<chrono::Utc>,
}

/// Quality degradation summary for a project
pub struct QualityDegradationSummary {
    pub project_id: i32,
    pub total_storyboards: i64,
    pub storyboards_with_degradation: i64,
    pub degradation_rate_percent: f64,
    pub common_degradation_stages: Vec<(String, String, i64)>, // (from_stage, to_stage, count)
}
```

### 2. Quality Comparison Queries

Add new query functions to `backend/src/production/quality_gate/comparison.rs`:

```rust
/// Fetch quality progression for a set of storyboards
pub async fn fetch_storyboard_quality_progression(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    storyboard_ids: &[i32],
) -> Result<Vec<StoryboardQualityProgression>, ApiError>

/// Detect quality degradation between stages
pub async fn detect_quality_degradation(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: Option<i32>,
) -> Result<QualityDegradationSummary, ApiError>

/// Compare quality metrics between two stages
pub async fn compare_stage_quality(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    from_stage: &str,
    to_stage: &str,
    storyboard_ids: &[i32],
) -> Result<Vec<QualityComparison>, ApiError>
```

### 3. Quality Degradation Detection Logic

**Degradation Criteria**:
- Overall score drops by ≥2 points between stages
- `passed` changes from true to false
- New bad_case appears in later stage
- Quality metrics (plot_coherence, character_consistency, etc.) drop significantly

**Detection Algorithm**:
```rust
fn detect_degradation(
    storyboard: &QualityMetrics,
    video: &QualityMetrics,
    output: &QualityMetrics,
) -> (bool, Vec<String>) {
    let mut degraded = false;
    let mut stages = Vec::new();
    
    // Check storyboard → video
    if let (Some(sb_score), Some(v_score)) = (storyboard.overall_score, video.overall_score) {
        if sb_score - v_score >= 2 {
            degraded = true;
            stages.push("storyboard_to_video".to_string());
        }
    }
    
    // Check video → output
    if let (Some(v_score), Some(o_score)) = (video.overall_score, output.overall_score) {
        if v_score - o_score >= 2 {
            degraded = true;
            stages.push("video_to_output".to_string());
        }
    }
    
    // Check bad case introduction
    if !storyboard.is_bad_case && video.is_bad_case {
        degraded = true;
        stages.push("storyboard_to_video".to_string());
    }
    if !video.is_bad_case && output.is_bad_case {
        degraded = true;
        stages.push("video_to_output".to_string());
    }
    
    (degraded, stages)
}
```

### 4. API Endpoints

Add new endpoints to expose quality comparison:

**GET `/api/v1/projects/{project_id}/quality/progression`**
- Query params: `scriptId`, `storyboardIds[]`
- Returns: `Vec<StoryboardQualityProgression>`
- Shows quality evolution for each storyboard

**GET `/api/v1/projects/{project_id}/quality/degradation`**
- Query params: `scriptId`, `threshold`
- Returns: `QualityDegradationSummary`
- Identifies storyboards with quality degradation

**GET `/api/v1/projects/{project_id}/quality/compare`**
- Query params: `fromStage`, `toStage`, `storyboardIds[]`
- Returns: `Vec<QualityComparison>`
- Compares quality between two specific stages

### 5. Integration with Existing Systems

**Quality Gate Integration**:
- After running quality gate, check for degradation from previous stage
- Log warning if degradation detected
- Optionally block if degradation is severe (configurable)

**Quality Review Integration**:
- When creating quality review, automatically compare with previous stage
- Store degradation flag in review metadata
- Link reviews across stages using `target_id`

**Assembly Integration**:
- Extend `ShortVideoCandidateQualitySummary` to include degradation metrics
- Add `quality_degradation_count` field
- Add `degradation_by_stage_transition` breakdown

### 6. Database Queries

**Quality Progression Query**:
```sql
WITH storyboard_quality AS (
  SELECT 
    target_id::int AS storyboard_id,
    MAX(overall_score) AS overall_score,
    BOOL_OR(passed) AS passed,
    BOOL_OR(is_bad_case) AS is_bad_case,
    COUNT(*) AS review_count,
    MAX(created_at) AS latest_review_at
  FROM app_quality_review
  WHERE user_id = $1
    AND project_id = $2
    AND target_type = 'storyboard'
    AND target_id = ANY($3)
  GROUP BY target_id
),
video_quality AS (
  SELECT 
    target_id::int AS storyboard_id,
    MAX(overall_score) AS overall_score,
    BOOL_OR(passed) AS passed,
    BOOL_OR(is_bad_case) AS is_bad_case,
    COUNT(*) AS review_count,
    MAX(created_at) AS latest_review_at
  FROM app_quality_review
  WHERE user_id = $1
    AND project_id = $2
    AND target_type = 'video'
    AND target_id = ANY($3)
  GROUP BY target_id
),
output_quality AS (
  SELECT 
    target_id::int AS storyboard_id,
    MAX(overall_score) AS overall_score,
    BOOL_OR(passed) AS passed,
    BOOL_OR(is_bad_case) AS is_bad_case,
    COUNT(*) AS review_count,
    MAX(created_at) AS latest_review_at
  FROM app_quality_review
  WHERE user_id = $1
    AND project_id = $2
    AND target_type = 'output'
    AND target_id = ANY($3)
  GROUP BY target_id
)
SELECT 
  sb.storyboard_id,
  sb.overall_score AS sb_score,
  v.overall_score AS video_score,
  o.overall_score AS output_score,
  sb.is_bad_case AS sb_bad_case,
  v.is_bad_case AS video_bad_case,
  o.is_bad_case AS output_bad_case
FROM storyboard_quality sb
LEFT JOIN video_quality v ON v.storyboard_id = sb.storyboard_id
LEFT JOIN output_quality o ON o.storyboard_id = sb.storyboard_id
```

**Degradation Detection Query**:
```sql
WITH quality_progression AS (
  -- Use above query
)
SELECT 
  COUNT(*) AS total_storyboards,
  COUNT(*) FILTER (
    WHERE (sb_score - video_score >= 2)
       OR (video_score - output_score >= 2)
       OR (NOT sb_bad_case AND video_bad_case)
       OR (NOT video_bad_case AND output_bad_case)
  ) AS storyboards_with_degradation
FROM quality_progression
```

## Implementation Plan

### Phase 1: Core Comparison Infrastructure
1. Create `backend/src/production/quality_gate/comparison.rs` module
2. Add `StoryboardQualityProgression` and related types
3. Implement `fetch_storyboard_quality_progression` query
4. Add unit tests for comparison logic

### Phase 2: Degradation Detection
1. Implement `detect_quality_degradation` function
2. Add degradation detection logic
3. Implement `compare_stage_quality` function
4. Add tests for degradation detection

### Phase 3: API Integration
1. Add quality comparison endpoints to routes
2. Extend `ShortVideoCandidateQualitySummary` with degradation metrics
3. Update assembly query to include degradation data
4. Add OpenAPI documentation

### Phase 4: Quality Gate Integration
1. Integrate degradation detection into quality gate flow
2. Add degradation warnings to quality gate output
3. Update quality gate tests to cover degradation scenarios
4. Add degradation metrics to quality gate memory

## Testing Strategy

### Unit Tests
- Test quality progression query with various stage combinations
- Test degradation detection with different score deltas
- Test bad case introduction detection
- Test empty/missing stage handling

### Integration Tests
- Test full pipeline: storyboard → video → output quality tracking
- Test degradation detection across multiple storyboards
- Test API endpoints with real data
- Test quality gate integration with degradation detection

### Property Tests
- Test degradation detection is monotonic (if A→B degrades and B→C degrades, A→C should degrade)
- Test score delta thresholds are consistent
- Test bad case propagation is tracked correctly

## Success Criteria

1. ✅ Can query quality metrics for storyboard, video, and output stages
2. ✅ Can detect quality degradation between stages
3. ✅ Can identify which stage transitions have degradation
4. ✅ Quality degradation is visible in assembly view
5. ✅ Quality gate logs warnings for degradation
6. ✅ All tests pass

## Future Enhancements

### Potential Improvements (Not Implemented)

1. **Automatic Rework Triggers**:
   - Automatically trigger rework when degradation detected
   - Route to appropriate stage for fixing
   - Example: Video degradation → re-generate video

2. **Quality Trend Analysis**:
   - Track quality trends over time
   - Identify systematic degradation patterns
   - Example: "Video generation consistently degrades quality by 15%"

3. **Stage-Specific Degradation Rules**:
   - Different degradation thresholds per stage
   - Different metrics matter at different stages
   - Example: Visual quality matters more for output than storyboard

4. **Quality Recovery Tracking**:
   - Track when quality improves after rework
   - Measure effectiveness of rework
   - Example: "Rework improved quality by 3 points"

5. **Cross-Project Quality Benchmarks**:
   - Compare quality across projects
   - Identify best practices
   - Example: "Projects using art_style_pack X have 20% less degradation"

## Files to Create/Modify

### New Files
- `backend/src/production/quality_gate/comparison.rs` - Quality comparison logic
- `backend/src/production/quality_gate/comparison_tests.rs` - Unit tests
- `.kiro/specs/短剧生成完善化/I.3-quality-comparison-storyboard-video-output.md` - This document

### Modified Files
- `backend/src/production/quality_gate/mod.rs` - Export comparison module
- `backend/src/projects/routes/types.rs` - Add quality progression types
- `backend/src/projects/routes/handlers/detail/assembly_query.rs` - Add degradation queries
- `backend/src/projects/routes/handlers/detail/short_video_assembly.rs` - Include degradation in response
- `backend/src/production/quality_gate/enforce.rs` - Integrate degradation detection
- `backend/src/projects/openapi.rs` - Add new types to OpenAPI

## Deployment Notes

1. **No Migration Required**: Uses existing `app_quality_review` table
2. **Backward Compatible**: New queries don't affect existing functionality
3. **Performance**: Queries use existing indexes on `user_id`, `project_id`, `target_type`, `target_id`
4. **Monitoring**: Watch for slow queries on large projects with many reviews

## Conclusion

This implementation extends the quality tracking system to provide comprehensive visibility into quality evolution across the content generation pipeline. By detecting quality degradation between stages, the system can alert users to problems early and guide them to the appropriate stage for fixing issues.

**Next Steps**:
- I.4: Promote quality nextAction to typed field for rework action
- I.5: Connect low-performance alert to rewrite/republish loop

