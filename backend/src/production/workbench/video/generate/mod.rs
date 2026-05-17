use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::Serialize;

use super::WorkbenchGenerateVideoBody;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_VIDEO_GENERATE};
use crate::production::workbench::generation_guards::assert_storyboards_ready_for_generation;
use crate::production::workbench::generation_profile::load_project_generation_profile;
use crate::production::workbench::meta::generate::constraints::VideoPromptConstraintPressure;
use crate::production::workbench::meta::generate::constraints::{
    derive_recent_quality_constraint_pressure, infer_adaptive_automation_memory_mode,
    RecentQualitySignalRow,
};
use crate::production::workbench::video_prompt_memory::{
    optimize_scoped_video_memory, AgentMemoryRow, StoryboardPromptSeedRow,
};
use crate::production::{enforce_quality_gate, run_quality_gate, QualityGateStage};
use crate::scope::http::require_script_write_scope_ref;
use crate::scope::OwnedScriptInProject;
use crate::settings::agent_memory::{
    load_project_automation_memory_policy, save_project_automation_memory_policy,
    AutomationMemoryMode, ProjectAutomationMemoryPolicy,
};
use crate::state::AppState;
use uuid::Uuid;

const VIDEO_NEGATIVE_PROMPT_MAX_CHARS: usize = 120;
const VIDEO_NEGATIVE_PROMPT_LEAN_MAX_CHARS: usize = 84;
const VIDEO_NEGATIVE_PROMPT_LEAN_FRAGMENT_LIMIT: usize = 2;
const VIDEO_NEGATIVE_REVIEW_BASE_LIMIT: i64 = 8;
const VIDEO_NEGATIVE_REVIEW_PER_STORYBOARD_ROWS: i64 = 4;
const VIDEO_NEGATIVE_REVIEW_MAX_LIMIT: i64 = 24;
const VIDEO_NEGATIVE_REJECTED_MEMORY_BASE_LIMIT: i64 = 8;
const VIDEO_NEGATIVE_REJECTED_MEMORY_PER_STORYBOARD_ROWS: i64 = 2;
const VIDEO_NEGATIVE_REJECTED_MEMORY_MAX_LIMIT: i64 = 12;
const VIDEO_NEGATIVE_SELECTED_MEMORY_BASE_LIMIT: i64 = 8;
const VIDEO_NEGATIVE_SELECTED_MEMORY_PER_STORYBOARD_ROWS: i64 = 2;
const VIDEO_NEGATIVE_SELECTED_MEMORY_SUMMARY_ROWS: i64 = 2;
const VIDEO_NEGATIVE_SELECTED_MEMORY_MAX_LIMIT: i64 = 14;

#[derive(Debug, Clone)]
struct NormalizedGenerateVideoUploadItem {
    storyboard_id: i32,
    source_url: String,
    prompt: Option<String>,
    negative_prompt: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct WorkbenchGenerateVideoResponse {
    enqueued: Vec<JobRow>,
    total: usize,
    negative_prompt: Option<String>,
    storyboard_negative_prompts: Vec<StoryboardNegativePrompt>,
    #[serde(default, skip_serializing_if = "is_zero_usize")]
    skipped_duplicate_count: usize,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    skipped_duplicate_storyboard_ids: Vec<i32>,
}

fn is_zero_usize(value: &usize) -> bool {
    *value == 0
}

/// Recent in-flight jobs with the same storyboard + model are treated as duplicates.
pub(super) const VIDEO_JOB_DEDUP_WINDOW_MINUTES: i64 = 5;

#[must_use]
pub(super) fn normalize_video_prompt_fingerprint(prompt: &str) -> String {
    prompt
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_ascii_lowercase()
}

fn payload_prompt_fingerprint(payload: &serde_json::Value) -> Option<String> {
    if let Some(fp) = payload
        .get("prompt_fingerprint")
        .and_then(|v| v.as_str())
        .map(str::trim)
        .filter(|s| !s.is_empty())
    {
        return Some(fp.to_string());
    }
    payload
        .get("prompt")
        .and_then(|p| p.as_str())
        .map(normalize_video_prompt_fingerprint)
}

pub(super) fn recent_video_job_matches_storyboard_model(
    payload: &serde_json::Value,
    storyboard_id: i32,
    model: &str,
    prompt_fingerprint: &str,
) -> bool {
    let Some(sb) = payload.get("storyboard_numeric_id") else {
        return false;
    };
    let sb_id = sb
        .as_i64()
        .or_else(|| sb.as_str().and_then(|s| s.parse().ok()));
    if sb_id != Some(i64::from(storyboard_id)) {
        return false;
    }
    if payload
        .get("model")
        .and_then(|m| m.as_str())
        .is_none_or(|m| m != model)
    {
        return false;
    }
    payload_prompt_fingerprint(payload).is_some_and(|fp| fp == prompt_fingerprint)
}

async fn load_recent_duplicate_video_storyboard_ids(
    pool: &sqlx::PgPool,
    project_numeric_id: i32,
    script_id: i32,
    candidates: &[(i32, String)],
    model: &str,
) -> Result<std::collections::HashSet<i32>, ApiError> {
    if candidates.is_empty() {
        return Ok(std::collections::HashSet::new());
    }
    let storyboard_ids: Vec<i32> = candidates.iter().map(|(id, _)| *id).collect();
    let rows = sqlx::query_as::<_, (i32, serde_json::Value)>(
        r#"
        SELECT (j.payload->>'storyboard_numeric_id')::int AS sb_id, j.payload
        FROM app_generation_job j
        WHERE j.kind = $1
          AND j.status IN ('queued', 'running')
          AND (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
          AND (j.payload->>'project_numeric_id')::int = $2
          AND (j.payload->>'script_id') ~ '^[0-9]+$'
          AND (j.payload->>'script_id')::int = $3
          AND (j.payload->>'storyboard_numeric_id') ~ '^[0-9]+$'
          AND (j.payload->>'storyboard_numeric_id')::int = ANY($4::int4[])
          AND j.created_at > NOW() - ($5::int * INTERVAL '1 minute')
        "#,
    )
    .bind(JOB_KIND_VIDEO_GENERATE)
    .bind(project_numeric_id)
    .bind(script_id)
    .bind(storyboard_ids)
    .bind(VIDEO_JOB_DEDUP_WINDOW_MINUTES)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut duplicates = std::collections::HashSet::new();
    for (sb_id, prompt_fp) in candidates {
        for (row_sb_id, payload) in &rows {
            if *row_sb_id == *sb_id
                && recent_video_job_matches_storyboard_model(payload, *sb_id, model, prompt_fp)
            {
                duplicates.insert(*sb_id);
            }
        }
    }
    Ok(duplicates)
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct QualityReviewSeedRow {
    target_type: Option<String>,
    target_id: Option<String>,
    bad_case_category: Option<String>,
    comments: Option<String>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct RecentQualitySignalSeedRow {
    target_type: Option<String>,
    target_id: Option<String>,
    passed: Option<bool>,
    overall_score: Option<i16>,
    dialogue_naturalness: Option<i16>,
    character_consistency: Option<i16>,
    visual_quality: Option<i16>,
    memory_delivery_priority_applied: Option<bool>,
    is_bad_case: bool,
    bad_case_category: Option<String>,
    comments: Option<String>,
    feedback_memory_focus_tags: Option<serde_json::Value>,
}

#[derive(Debug)]
struct ScoredNegativeFragment {
    score: i32,
    order: usize,
    fragment: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct StoryboardNegativePrompt {
    storyboard_id: i32,
    negative_prompt: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct AutoNegativePromptSelection {
    pub(crate) prompt: Option<String>,
    pub(crate) fragment_count: usize,
    pub(crate) candidate_fragment_count: usize,
    pub(crate) saved_fragment_count: usize,
    pub(crate) saved_chars: usize,
    pub(crate) budget_tier: &'static str,
    pub(crate) review_fragment_count: usize,
    pub(crate) rejected_memory_fragment_count: usize,
    pub(crate) used_pending_observation_fallback: bool,
}

#[derive(Debug, Clone)]
struct StoryboardNegativePromptContext {
    storyboard_id: i32,
    storyboard_review_rows: Vec<QualityReviewSeedRow>,
    recent_quality_pressure: Option<VideoPromptConstraintPressure>,
    selected_rows: Vec<AgentMemoryRow>,
    storyboard_row: Option<StoryboardPromptSeedRow>,
    current_prompt_seed: Option<String>,
    subject_candidates: Vec<String>,
}

#[derive(Debug)]
pub(crate) struct StoryboardNegativePromptRuntime {
    pub(crate) storyboard_id: i32,
    pub(crate) selection: AutoNegativePromptSelection,
    pub(crate) pending_observation_candidates: Vec<String>,
    #[allow(dead_code)]
    pub(crate) rejected_rows: Vec<AgentMemoryRow>,
    #[allow(dead_code)]
    pub(crate) selected_rows: Vec<AgentMemoryRow>,
    pub(crate) prompt_support_rows: Vec<AgentMemoryRow>,
    pub(crate) storyboard_row: Option<StoryboardPromptSeedRow>,
    pub(crate) current_prompt_seed: Option<String>,
    pub(crate) subject_candidates: Vec<String>,
}

impl AutoNegativePromptSelection {
    #[cfg_attr(not(test), allow(dead_code))]
    pub(in crate::production::workbench::video::generate) fn as_deref(&self) -> Option<&str> {
        self.prompt.as_deref()
    }

    pub(crate) fn source_label(&self) -> Option<&'static str> {
        self.prompt.as_ref()?;
        if self.used_pending_observation_fallback {
            return Some("pending_rejected_observation");
        }
        match (
            self.review_fragment_count > 0,
            self.rejected_memory_fragment_count > 0,
        ) {
            (true, true) => Some("review+rejected_memory"),
            (true, false) => Some("review"),
            (false, true) => Some("rejected_memory"),
            (false, false) => None,
        }
    }
}

fn merge_negative_selection_constraint_pressure(
    selections: impl Iterator<Item = AutoNegativePromptSelection>,
) -> Option<VideoPromptConstraintPressure> {
    let merged = selections.fold(
        VideoPromptConstraintPressure::default(),
        |pressure, selection| {
            pressure.merge(VideoPromptConstraintPressure::from_runtime_constraints(
                Some(&selection),
                None,
            ))
        },
    );
    merged.has_active_guardrail().then_some(merged)
}

async fn apply_adaptive_project_memory_mode(
    pool: &sqlx::PgPool,
    user_id: Uuid,
    project_id: i32,
    recent_rows: &[RecentQualitySignalRow],
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Result<AutomationMemoryMode, ApiError> {
    let current =
        load_project_automation_memory_policy(pool, user_id, project_id, "productionAgent").await?;
    if current.mode == AutomationMemoryMode::Off {
        return Ok(AutomationMemoryMode::Off);
    }
    let next_mode = infer_adaptive_automation_memory_mode(recent_rows, constraint_pressure);
    if current.mode != next_mode {
        save_project_automation_memory_policy(
            pool,
            user_id,
            project_id,
            "productionAgent",
            &ProjectAutomationMemoryPolicy { mode: next_mode },
        )
        .await?;
    }
    Ok(next_mode)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum VideoNegativePromptBudgetTier {
    Lean,
    Expanded,
}

impl VideoNegativePromptBudgetTier {
    fn as_str(self) -> &'static str {
        match self {
            Self::Lean => "lean",
            Self::Expanded => "expanded",
        }
    }
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/generate-video",
    operation_id = "postProductionWorkbenchGenerateVideoV1",
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
pub(in crate::production) async fn post_workbench_generate_video(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchGenerateVideoBody>,
) -> Result<JsonResponse<WorkbenchGenerateVideoResponse>, ApiError> {
    let (user_id, pool, scope_row) = require_script_write_scope_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
    )
    .await?;
    let response = workbench_enqueue_video_jobs_from_body(
        user_id,
        pool,
        &scope_row,
        body,
        Some(&headers),
        &state.billing_config,
    )
    .await?;
    Ok(JsonResponse(response))
}

/// Shared core for **`POST …/workbench/generate-video`** and batch orchestration (**L1**).
pub(crate) async fn workbench_enqueue_video_jobs_from_body(
    user_id: Uuid,
    pool: &sqlx::PgPool,
    scope_row: &OwnedScriptInProject,
    body: WorkbenchGenerateVideoBody,
    http_headers: Option<&HeaderMap>,
    billing_config: &crate::metering::BillingConfig,
) -> Result<WorkbenchGenerateVideoResponse, ApiError> {
    if body.track_id <= 0 {
        return Err(crate::error::bad_request_i18n(
            "trackId must be a positive integer",
            "trackId 必须是正整数",
        ));
    }
    if body.upload_data.is_empty() {
        return Err(crate::error::bad_request_i18n(
            "uploadData must not be empty",
            "uploadData 不能为空",
        ));
    }
    crate::error::validate_non_empty_string(body.model.trim(), "model")?;
    if body.duration <= 0 {
        return Err(crate::error::bad_request_i18n(
            "duration must be a positive integer",
            "duration 必须是正整数",
        ));
    }

    let upload_items = normalize_upload_sources(&body.upload_data)?;
    let storyboard_ids = upload_items
        .iter()
        .map(|item| item.storyboard_id)
        .collect::<Vec<_>>();
    ensure_track_in_scope(
        pool,
        scope_row.project_id,
        scope_row.script_id,
        body.track_id,
    )
    .await?;
    ensure_storyboards_in_scope(pool, scope_row.script_id, &storyboard_ids).await?;
    assert_storyboards_ready_for_generation(
        pool,
        scope_row.project_id,
        user_id,
        body.script_id,
        &storyboard_ids,
    )
    .await?;
    let generation_profile = load_project_generation_profile(pool, scope_row.project_id).await?;
    let generation_profile_label = match generation_profile.tier {
        crate::production::workbench::generation_profile::GenerationProfileTier::Draft => "draft",
        crate::production::workbench::generation_profile::GenerationProfileTier::Standard => {
            "standard"
        }
        crate::production::workbench::generation_profile::GenerationProfileTier::Premium => {
            "premium"
        }
    };
    let mut text_inputs = upload_items
        .iter()
        .filter_map(|item| item.prompt.clone())
        .collect::<Vec<_>>();
    if !body.prompt.trim().is_empty() {
        text_inputs.push(body.prompt.clone());
    }
    let (gate, strategy) = run_quality_gate(
        pool,
        user_id,
        scope_row.project_numeric_id,
        body.script_id,
        QualityGateStage::VideoGenerate,
        &storyboard_ids,
        &text_inputs,
    )
    .await?;
    enforce_quality_gate(QualityGateStage::VideoGenerate, &gate, strategy)?;
    let recent_quality_rows = memory_integration::load_recent_quality_signal_rows(
        pool,
        user_id,
        scope_row.project_numeric_id,
        body.script_id,
        &storyboard_ids,
    )
    .await?;
    let recent_quality_rows = recent_quality_rows
        .into_iter()
        .map(RecentQualitySignalRow::from)
        .collect::<Vec<_>>();
    let recent_quality_pressure = derive_recent_quality_constraint_pressure(&recent_quality_rows);
    let storyboard_negative_prompt_details = memory_integration::load_auto_negative_prompt_details(
        pool,
        user_id,
        scope_row.project_numeric_id,
        body.script_id,
        &storyboard_ids,
    )
    .await?;
    let constraint_pressure = merge_negative_selection_constraint_pressure(
        storyboard_negative_prompt_details.values().cloned(),
    )
    .map(|pressure| pressure.merge(recent_quality_pressure))
    .or(recent_quality_pressure);
    apply_adaptive_project_memory_mode(
        pool,
        user_id,
        scope_row.project_numeric_id,
        &recent_quality_rows,
        constraint_pressure,
    )
    .await?;
    optimize_scoped_video_memory(pool, user_id, scope_row.project_numeric_id, body.script_id)
        .await?;

    let aspect_ratio = load_project_aspect_ratio(pool, scope_row.project_id)
        .await?
        .unwrap_or_else(|| "16:9".to_string());
    let project_mode = load_project_mode(pool, scope_row.project_id).await?;
    let storyboard_negative_prompts = storyboard_negative_prompt_details
        .into_iter()
        .map(|(storyboard_id, selection)| (storyboard_id, selection.prompt))
        .collect::<std::collections::HashMap<_, _>>();
    let provider = infer_video_provider(&body.model);
    let duration_label = format!("{}s", body.duration);
    let default_prompt = body.prompt.trim().to_string();
    let model = body.model.trim().to_string();
    let resolution = body.resolution.trim().to_string();
    let mode = body.mode.trim().to_string();
    let mut dedup_candidates = Vec::with_capacity(upload_items.len());
    for item in &upload_items {
        let prompt_seed = resolve_storyboard_prompt(item, &default_prompt)?;
        let prompt = apply_project_mode_prompt_preset(&prompt_seed, project_mode.as_deref());
        dedup_candidates.push((
            item.storyboard_id,
            normalize_video_prompt_fingerprint(&prompt),
        ));
    }
    let recent_duplicate_storyboards = load_recent_duplicate_video_storyboard_ids(
        pool,
        scope_row.project_numeric_id,
        body.script_id,
        &dedup_candidates,
        &model,
    )
    .await?;

    let mut enqueued = Vec::with_capacity(upload_items.len());
    let mut response_negative_prompts = Vec::with_capacity(storyboard_ids.len());
    let mut skipped_duplicate_storyboard_ids = Vec::new();
    for item in upload_items {
        if recent_duplicate_storyboards.contains(&item.storyboard_id) {
            skipped_duplicate_storyboard_ids.push(item.storyboard_id);
            continue;
        }
        let prompt_seed = resolve_storyboard_prompt(&item, &default_prompt)?;
        let prompt = apply_project_mode_prompt_preset(&prompt_seed, project_mode.as_deref());
        let prompt_fingerprint = normalize_video_prompt_fingerprint(&prompt);
        let merged_negative_prompt = merge_negative_prompts(
            merge_negative_prompts(
                body.negative_prompt.as_deref(),
                item.negative_prompt.as_deref(),
            )
            .as_deref(),
            storyboard_negative_prompts
                .get(&item.storyboard_id)
                .and_then(|value| value.as_deref()),
        );
        sqlx::query(
            r#"
            UPDATE app_storyboard
            SET prompt = $2,
                duration = $3,
                track_id = $4,
                state = '生成中',
                updated_at = NOW()
            WHERE script_id = $1
              AND numeric_id = $5
            "#,
        )
        .bind(scope_row.script_id)
        .bind(&prompt)
        .bind(&duration_label)
        .bind(body.track_id)
        .bind(item.storyboard_id)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let payload = serde_json::json!({
            "source": "production.workbench.generate-video",
            "project_uuid": scope_row.project_id,
            "project_numeric_id": scope_row.project_numeric_id,
            "script_id": body.script_id,
            "script_numeric_id": body.script_id,
            "storyboard_numeric_id": item.storyboard_id,
            "provider": provider,
            "model": &model,
            "prompt_fingerprint": &prompt_fingerprint,
            "mode": &mode,
            "prompt": &prompt,
            "negative_prompt": merged_negative_prompt.clone(),
            "duration": body.duration,
            "resolution": &resolution,
            "aspect_ratio": &aspect_ratio,
            "audio": body.audio,
            "track_id": body.track_id,
            "image_url": item.source_url,
            "generation_profile": generation_profile_label,
            "memory_budget_tier": generation_profile.tier.default_memory_budget_tier(),
        });
        let row = enqueue_generation_job(
            pool,
            user_id,
            JOB_KIND_VIDEO_GENERATE,
            payload,
            http_headers,
            billing_config,
        )
        .await?;
        enqueued.push(row);
        response_negative_prompts.push(StoryboardNegativePrompt {
            storyboard_id: item.storyboard_id,
            negative_prompt: merged_negative_prompt,
        });
    }

    let total = enqueued.len();
    let skipped_duplicate_count = skipped_duplicate_storyboard_ids.len();
    Ok(WorkbenchGenerateVideoResponse {
        enqueued,
        total,
        negative_prompt: body.negative_prompt.clone(),
        storyboard_negative_prompts: response_negative_prompts,
        skipped_duplicate_count,
        skipped_duplicate_storyboard_ids,
    })
}

// Module declarations
mod batch_candidate_clips;
mod consumer_examples;
mod fragment_operations;
mod fragment_parsing;
mod memory_integration;
mod negative_prompt_analysis;
mod negative_prompt_builder;
mod negative_prompt_core;
mod negative_prompt_risk;
mod quality_control;
mod scene_diagnostics;
mod short_video_config;
mod utils;

#[cfg(test)]
mod tests;

// Re-exports
pub(crate) use memory_integration::load_storyboard_negative_prompt_runtime;
pub(crate) use quality_control::{
    infer_negative_fragments_from_comments, map_bad_case_category_with_comments,
};

// Re-export for potential future use by other modules
#[allow(unused_imports)]
pub(crate) use short_video_config::{
    load_storyboard_generation_config, StoryboardGenerationConfig,
};

#[allow(unused_imports)]
pub(crate) use batch_candidate_clips::__path_post_workbench_batch_generate_candidate_clips;
pub(in crate::production) use batch_candidate_clips::post_workbench_batch_generate_candidate_clips;

// Internal imports for handler
use fragment_operations::merge_negative_prompts;
use memory_integration::{
    apply_project_mode_prompt_preset, ensure_storyboards_in_scope, ensure_track_in_scope,
    load_project_aspect_ratio, load_project_mode, normalize_upload_sources,
    resolve_storyboard_prompt,
};
use utils::infer_video_provider;
