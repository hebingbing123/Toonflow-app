use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::Serialize;
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::production::workbench::meta::common::{
    clip_prompt_fragment, extract_key_value, negative_constraint_conflicts_with_storyboard_style,
    normalize_prompt_text, parse_positive_int, parse_structured_storyboard_description,
    StructuredStoryboardDescription,
};
use crate::production::workbench::video::generate::{
    load_storyboard_negative_prompt_runtime, AutoNegativePromptSelection,
    StoryboardNegativePromptRuntime,
};
use crate::production::workbench::video_prompt_memory::{
    compact_video_continuity_note, compact_video_style_prompt_note,
    contextual_style_memory_value_for_storyboard, optimize_scoped_video_memory,
    select_prioritized_video_style_note, select_selected_video_memory_notes_for_storyboard,
    select_subject_role_video_style_memory_notes,
    select_subject_role_video_style_memory_notes_for_storyboard, selected_memory_subject_aliases,
    storyboard_prompt_seed, AgentMemoryRow, StoryboardPromptSeedRow,
};
use crate::scope::http::require_authenticated;
use crate::scope::http::require_owned_numeric_script_scope_user_pool;
use crate::state::AppState;

mod builder;
pub(crate) mod constraints;
mod context;
mod director;
mod handlers;
mod memory;
#[cfg(test)]
mod tests;
mod tokens;

use constraints::VideoPromptConstraintPressure;
use constraints::{derive_recent_quality_constraint_pressure, RecentQualitySignalRow};
use handlers::{
    GenerateVideoPromptBody, GenerateVideoPromptDiagnostics, GenerateVideoPromptResponse,
};
use tokens::*;

use builder::*;
use context::*;
use director::*;
use memory::*;

// moved to `generate_tokens.rs`

#[derive(Debug, sqlx::FromRow)]
struct RecentQualitySignalDbRow {
    passed: Option<bool>,
    overall_score: Option<i16>,
    dialogue_naturalness: Option<i16>,
    character_consistency: Option<i16>,
    visual_quality: Option<i16>,
    memory_delivery_priority_applied: Option<bool>,
    is_bad_case: bool,
    bad_case_category: Option<String>,
    comments: Option<String>,
}

impl From<RecentQualitySignalDbRow> for RecentQualitySignalRow {
    fn from(value: RecentQualitySignalDbRow) -> Self {
        Self {
            passed: value.passed,
            overall_score: value.overall_score,
            dialogue_naturalness: value.dialogue_naturalness,
            character_consistency: value.character_consistency,
            visual_quality: value.visual_quality,
            memory_delivery_priority_applied: value.memory_delivery_priority_applied,
            is_bad_case: value.is_bad_case,
            bad_case_category: value.bad_case_category,
            comments: value.comments,
        }
    }
}

async fn load_recent_quality_constraint_pressure(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
    storyboard_id: Option<i32>,
) -> Result<Option<VideoPromptConstraintPressure>, ApiError> {
    let storyboard_target = storyboard_id.filter(|id| *id > 0).map(|id| id.to_string());
    let rows = sqlx::query_as::<_, RecentQualitySignalDbRow>(
        r#"
        SELECT
          passed,
          overall_score,
          dialogue_naturalness,
          character_consistency,
          visual_quality,
          memory_delivery_priority_applied,
          is_bad_case,
          bad_case_category,
          comments
        FROM app_quality_review
        WHERE user_id = $1
          AND project_id = $2
          AND script_id = $3
          AND target_type IN ('storyboard', 'output', 'video', 'asset')
          AND (
            $4::text IS NULL
            OR target_id = $4
            OR target_id IS NULL
          )
        ORDER BY
          CASE WHEN $4::text IS NOT NULL AND target_id = $4 THEN 0 ELSE 1 END,
          created_at DESC
        LIMIT 12
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(script_id)
    .bind(storyboard_target)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let rows = rows
        .into_iter()
        .map(RecentQualitySignalRow::from)
        .collect::<Vec<_>>();
    Ok(derive_recent_quality_constraint_pressure(&rows))
}

fn split_prompt_note_fragments(note: &str) -> impl Iterator<Item = String> + '_ {
    note.split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum VideoPromptMemoryBudgetTier {
    Lean,
    Expanded,
}

impl VideoPromptMemoryBudgetTier {
    fn as_str(self) -> &'static str {
        match self {
            Self::Lean => "lean",
            Self::Expanded => "expanded",
        }
    }
}

fn build_auto_quality_review_model_params(
    diagnostics: &GenerateVideoPromptDiagnostics,
) -> serde_json::Value {
    json!({
        "source": "production.workbench.generate-video-prompt",
        "diagnostics": {
            "promptChars": diagnostics.prompt_chars,
            "negativePromptChars": diagnostics.negative_prompt_chars,
            "negativeConstraintCount": diagnostics.negative_constraint_count,
            "negativeBudgetTier": diagnostics.negative_budget_tier,
            "autoNegativeSource": diagnostics.auto_negative_source,
            "autoNegativeReviewFragmentCount": diagnostics.auto_negative_review_fragment_count,
            "autoNegativeMemoryFragmentCount": diagnostics.auto_negative_memory_fragment_count,
            "observationNoteChars": diagnostics.observation_note_chars,
            "memoryBudgetTier": diagnostics.memory_budget_tier,
            "memoryTopCandidateScore": diagnostics.memory_top_candidate_score,
            "memorySelectedPrimaryBucket": diagnostics.memory_selected_primary_bucket,
            "memoryLowValueCandidateSkipped": diagnostics.memory_low_value_candidate_skipped,
            "memoryStyleChars": diagnostics.memory_style_chars,
            "memoryVisualChars": diagnostics.memory_visual_chars,
            "memoryDeliveryChars": diagnostics.memory_delivery_chars,
            "memoryHitBuckets": diagnostics.memory_hit_buckets,
            "memorySuppressedBuckets": diagnostics.memory_suppressed_buckets,
            "memoryHitBucketCounts": diagnostics.memory_hit_bucket_counts,
            "memorySuppressedBucketCounts": diagnostics.memory_suppressed_bucket_counts,
            "memoryDeliveryPriorityApplied": diagnostics.memory_delivery_priority_applied,
            "recentQualityMemoryBiases": diagnostics.recent_quality_memory_biases,
            "memoryStyleAnchorCount": diagnostics.memory_style_anchor_count,
            "memoryDeliveryAnchorCount": diagnostics.memory_delivery_anchor_count,
            "memoryOptimizationApplied": diagnostics.memory_optimization_applied,
            "memoryOptimizationRemovedRows": diagnostics.memory_optimization_removed_rows,
            "memoryOptimizationRemovedChars": diagnostics.memory_optimization_removed_chars,
            "memoryOptimizationRemovedVisualRows": diagnostics.memory_optimization_removed_visual_rows,
            "memoryOptimizationRemovedDuplicateRows": diagnostics.memory_optimization_removed_duplicate_rows,
            "directorManualYieldedToMemory": diagnostics.director_manual_yielded_to_memory,
            "directorManualYieldedChars": diagnostics.director_manual_yielded_chars,
            "directorPerformanceTrimmedChars": diagnostics.director_performance_trimmed_chars,
            "directorAnchorSavedChars": diagnostics.director_anchor_saved_chars,
            "continuityNoteCount": diagnostics.continuity_note_count,
            "continuityNoteChars": diagnostics.continuity_note_chars,
            "usesReferenceFrame": diagnostics.uses_reference_frame,
        }
    })
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/generate-video-prompt",
    operation_id = "postProductionWorkbenchGenerateVideoPromptV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_workbench_generate_video_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GenerateVideoPromptBody>,
) -> Result<JsonResponse<GenerateVideoPromptResponse>, ApiError> {
    let (user_id, pool) = require_owned_numeric_script_scope_user_pool(
        &state,
        &headers,
        body.project_id,
        body.script_id,
    )
    .await?;
    let memory_optimization = if body.storyboard_id.is_some_and(|id| id > 0) {
        Some(optimize_scoped_video_memory(pool, user_id, body.project_id, body.script_id).await?)
    } else {
        None
    };
    let single_storyboard_runtime =
        if let Some(storyboard_id) = body.storyboard_id.filter(|id| *id > 0) {
            Some(
                load_storyboard_negative_prompt_runtime(
                    pool,
                    user_id,
                    body.project_id,
                    body.script_id,
                    storyboard_id,
                )
                .await?,
            )
        } else {
            None
        };
    let negative_prompt_selection = single_storyboard_runtime
        .as_ref()
        .map(|runtime| runtime.selection.clone());
    let observation_note = single_storyboard_runtime
        .as_ref()
        .filter(|runtime| runtime.selection.prompt.is_none())
        .and_then(build_pending_video_observation_note_from_runtime);
    let constraint_pressure = VideoPromptConstraintPressure::from_runtime_constraints(
        negative_prompt_selection.as_ref(),
        observation_note.as_deref(),
    );
    let constraint_pressure = constraint_pressure.unwrap_or_default().merge(
        load_recent_quality_constraint_pressure(
            pool,
            user_id,
            body.project_id,
            body.script_id,
            body.storyboard_id,
        )
        .await?,
    );
    let constraint_pressure = constraint_pressure
        .has_active_guardrail()
        .then_some(constraint_pressure);
    let context = load_video_prompt_context(
        pool,
        user_id,
        body.project_id,
        body.script_id,
        body.storyboard_id,
        single_storyboard_runtime.as_ref(),
        constraint_pressure,
    )
    .await?;
    let negative_prompt = negative_prompt_selection
        .as_ref()
        .and_then(|selection| selection.prompt.clone());
    let prompt_result = build_video_prompt_with_constraint_pressure(
        body.description.as_deref(),
        body.image_url.as_deref(),
        context.as_ref(),
        constraint_pressure,
    );
    let duration = resolve_video_prompt_duration(
        body.duration_hint,
        body.description.as_deref(),
        context.as_ref(),
    );

    let diagnostics = prompt_result
        .diagnostics
        .with_runtime_notes(
            negative_prompt_selection.as_ref(),
            observation_note.as_deref(),
        )
        .with_memory_optimization(memory_optimization.as_ref());

    if body.auto_quality_review {
        let pool = pool.clone();
        let model_name = "runway-gen-2".to_string();
        let project_id = body.project_id;
        let script_id = body.script_id;
        let target_type = if body.storyboard_id.is_some_and(|id| id > 0) {
            "storyboard".to_string()
        } else {
            "output".to_string()
        };
        let target_id = body
            .storyboard_id
            .filter(|id| *id > 0)
            .map(|id| id.to_string());
        let memory_delivery_priority_applied = diagnostics.memory_delivery_priority_applied;
        let model_params = build_auto_quality_review_model_params(&diagnostics);
        tokio::spawn(async move {
            let _ = sqlx::query(
                r#"
                INSERT INTO app_quality_review (
                  user_id, project_id, script_id, job_id,
                  target_type, target_id, source,
                  model_name, model_params,
                  memory_delivery_priority_applied,
                  is_bad_case
                )
                VALUES ($1, $2, $3, NULL, $4, $5, 'auto', $6, $7, $8, false)
                "#,
            )
            .bind(user_id)
            .bind(project_id)
            .bind(script_id)
            .bind(target_type)
            .bind(target_id)
            .bind(model_name)
            .bind(model_params)
            .bind(memory_delivery_priority_applied)
            .execute(&pool)
            .await;
        });
    }

    Ok(JsonResponse(GenerateVideoPromptResponse {
        prompt: prompt_result.prompt,
        negative_prompt,
        observation_note,
        diagnostics,
        model: "runway-gen-2".to_string(),
        duration,
    }))
}

#[derive(Debug, Clone, Default)]
struct VideoPromptContext {
    storyboard_prompt: Option<String>,
    storyboard_video_desc: Option<String>,
    storyboard_duration: Option<String>,
    #[allow(dead_code)]
    storyboard_prompt_seed: Option<String>,
    project_art_style: Option<String>,
    project_director_manual: Option<String>,
    script_role_anchors: Vec<String>,
    script_scene_anchors: Vec<String>,
    script_tool_anchors: Vec<String>,
    memory_style_notes: Vec<String>,
    continuity_notes: Vec<String>,
}

#[derive(Debug)]
struct VideoPromptBuildResult {
    prompt: String,
    diagnostics: GenerateVideoPromptDiagnostics,
}

#[derive(Debug, Default)]
struct VideoPromptStyleAnchorBuild {
    anchors: Vec<String>,
    memory_style_anchor_count: usize,
    memory_delivery_anchor_count: usize,
    memory_delivery_priority_applied: bool,
    memory_top_candidate_score: i32,
    memory_selected_primary_bucket: Option<String>,
    memory_low_value_candidate_skipped: bool,
    memory_hit_buckets: Vec<String>,
    memory_suppressed_buckets: Vec<String>,
    memory_hit_bucket_counts: std::collections::BTreeMap<String, usize>,
    memory_suppressed_bucket_counts: std::collections::BTreeMap<String, usize>,
    director_manual_yielded_to_memory: bool,
    director_manual_yielded_chars: usize,
    director_performance_trimmed_chars: usize,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct VideoModelDetailResponse {
    model_id: String,
    model_name: String,
    provider: String,
    max_duration: i32,
    resolutions: Vec<String>,
    features: Vec<String>,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/get-video-model-detail",
    operation_id = "postProductionWorkbenchGetVideoModelDetailV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_workbench_get_video_model_detail(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<JsonResponse<VideoModelDetailResponse>, ApiError> {
    require_authenticated(&state, &headers)?;

    Ok(JsonResponse(VideoModelDetailResponse {
        model_id: "gen-2".to_string(),
        model_name: "Gen-2".to_string(),
        provider: "runway".to_string(),
        max_duration: 16,
        resolutions: vec!["720p".to_string(), "1080p".to_string()],
        features: vec![
            "text-to-video".to_string(),
            "image-to-video".to_string(),
            "motion-brush".to_string(),
        ],
    }))
}
