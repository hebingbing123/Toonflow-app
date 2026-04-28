use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::Serialize;
use sqlx::PgPool;
use std::collections::{BTreeSet, HashMap};
use uuid::Uuid;

use super::WorkbenchGenerateVideoBody;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_VIDEO_GENERATE};
use crate::production::types::GenerateVideoUploadItem;
use crate::production::workbench::meta::common::negative_constraint_conflicts_with_storyboard_style;
use crate::production::workbench::video_prompt_memory::{
    clip_prompt_fragment, compact_video_style_prompt_note, extract_key_value,
    normalize_prompt_text, parse_structured_storyboard_description,
    select_prioritized_video_style_note, select_project_video_style_memory_notes_for_storyboard,
    select_rejected_video_memory_notes_and_observation_candidates_for_subject,
    select_script_video_style_memory_notes_for_storyboard, select_selected_video_memory_notes,
    select_subject_role_video_style_memory_notes_for_storyboard, selected_memory_subject_aliases,
    split_prompt_note_fragments, storyboard_prompt_seed, AgentMemoryRow, StoryboardPromptSeedRow,
    StructuredStoryboardDescription,
};
use crate::scope::http::require_owned_numeric_script_scope;
use crate::state::AppState;

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

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct WorkbenchGenerateVideoResponse {
    enqueued: Vec<JobRow>,
    total: usize,
    negative_prompt: Option<String>,
    storyboard_negative_prompts: Vec<StoryboardNegativePrompt>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct QualityReviewSeedRow {
    target_type: Option<String>,
    target_id: Option<String>,
    bad_case_category: Option<String>,
    comments: Option<String>,
}

#[derive(Debug)]
struct ScoredNegativeFragment {
    score: i32,
    order: usize,
    fragment: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct StoryboardNegativePrompt {
    storyboard_id: i32,
    negative_prompt: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct AutoNegativePromptSelection {
    pub(crate) prompt: Option<String>,
    pub(crate) fragment_count: usize,
    pub(crate) budget_tier: &'static str,
    pub(crate) review_fragment_count: usize,
    pub(crate) rejected_memory_fragment_count: usize,
    pub(crate) used_pending_observation_fallback: bool,
}

#[derive(Debug, Clone)]
struct StoryboardNegativePromptContext {
    storyboard_id: i32,
    storyboard_review_rows: Vec<QualityReviewSeedRow>,
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
    pub(crate) rejected_rows: Vec<AgentMemoryRow>,
    pub(crate) selected_rows: Vec<AgentMemoryRow>,
    pub(crate) prompt_support_rows: Vec<AgentMemoryRow>,
    pub(crate) storyboard_row: Option<StoryboardPromptSeedRow>,
    pub(crate) current_prompt_seed: Option<String>,
    pub(crate) subject_candidates: Vec<String>,
}

impl AutoNegativePromptSelection {
    fn as_deref(&self) -> Option<&str> {
        self.prompt.as_deref()
    }

    pub(crate) fn source_label(&self) -> Option<&'static str> {
        if self.prompt.is_none() {
            return None;
        }
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
    if body.track_id <= 0 {
        return Err(ApiError::BadRequest(
            "trackId must be a positive integer".into(),
        ));
    }
    if body.upload_data.is_empty() {
        return Err(ApiError::BadRequest("uploadData must not be empty".into()));
    }
    if body.prompt.trim().is_empty() {
        return Err(ApiError::BadRequest("prompt must not be empty".into()));
    }
    if body.model.trim().is_empty() {
        return Err(ApiError::BadRequest("model must not be empty".into()));
    }
    if body.duration <= 0 {
        return Err(ApiError::BadRequest(
            "duration must be a positive integer".into(),
        ));
    }

    let (user_id, pool, scope_row) =
        require_owned_numeric_script_scope(&state, &headers, body.project_id, body.script_id)
            .await?;
    let upload_sources = normalize_upload_sources(&body.upload_data)?;
    let storyboard_ids = upload_sources.keys().copied().collect::<Vec<_>>();
    ensure_track_in_scope(
        pool,
        scope_row.project_id,
        scope_row.script_id,
        body.track_id,
    )
    .await?;
    ensure_storyboards_in_scope(pool, scope_row.script_id, &storyboard_ids).await?;

    let aspect_ratio = load_project_aspect_ratio(pool, scope_row.project_id)
        .await?
        .unwrap_or_else(|| "16:9".to_string());
    let storyboard_negative_prompts = load_auto_negative_prompts(
        pool,
        user_id,
        body.project_id,
        body.script_id,
        &storyboard_ids,
    )
    .await?;
    let provider = infer_video_provider(&body.model);
    let duration_label = format!("{}s", body.duration);
    let prompt = body.prompt.trim().to_string();
    let model = body.model.trim().to_string();
    let resolution = body.resolution.trim().to_string();
    let mode = body.mode.trim().to_string();

    let mut enqueued = Vec::with_capacity(upload_sources.len());
    let mut response_negative_prompts = Vec::with_capacity(storyboard_ids.len());
    for (storyboard_numeric_id, source_url) in upload_sources {
        let merged_negative_prompt = merge_negative_prompts(
            body.negative_prompt.as_deref(),
            storyboard_negative_prompts
                .get(&storyboard_numeric_id)
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
        .bind(storyboard_numeric_id)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let payload = serde_json::json!({
            "source": "production.workbench.generate-video",
            "project_numeric_id": body.project_id,
            "script_id": body.script_id,
            "storyboard_numeric_id": storyboard_numeric_id,
            "provider": provider,
            "model": &model,
            "mode": &mode,
            "prompt": &prompt,
            "negative_prompt": merged_negative_prompt.clone(),
            "duration": body.duration,
            "resolution": &resolution,
            "aspect_ratio": &aspect_ratio,
            "audio": body.audio,
            "track_id": body.track_id,
            "image_url": source_url,
        });
        let row = enqueue_generation_job(pool, user_id, JOB_KIND_VIDEO_GENERATE, payload).await?;
        enqueued.push(row);
        response_negative_prompts.push(StoryboardNegativePrompt {
            storyboard_id: storyboard_numeric_id,
            negative_prompt: merged_negative_prompt,
        });
    }

    let total = enqueued.len();
    Ok(JsonResponse(WorkbenchGenerateVideoResponse {
        enqueued,
        total,
        negative_prompt: body.negative_prompt.clone(),
        storyboard_negative_prompts: response_negative_prompts,
    }))
}

fn normalize_upload_sources(
    items: &[GenerateVideoUploadItem],
) -> Result<HashMap<i32, String>, ApiError> {
    let mut seen = BTreeSet::new();
    let mut normalized = HashMap::with_capacity(items.len());
    for item in items {
        if item.id <= 0 {
            return Err(ApiError::BadRequest(
                "each uploadData.id must be a positive integer".into(),
            ));
        }
        if !seen.insert(item.id) {
            return Err(ApiError::BadRequest(
                "uploadData must not contain duplicate storyboard ids".into(),
            ));
        }
        let source = item.sources.trim();
        if source.is_empty() {
            return Err(ApiError::BadRequest(
                "each uploadData.sources must not be empty".into(),
            ));
        }
        let parsed = reqwest::Url::parse(source)
            .map_err(|e| ApiError::BadRequest(format!("invalid uploadData.sources URL: {e}")))?;
        match parsed.scheme() {
            "http" | "https" => {}
            other => {
                return Err(ApiError::BadRequest(format!(
                    "unsupported uploadData.sources scheme: {other} (expected http/https)"
                )));
            }
        }
        normalized.insert(item.id, source.to_string());
    }
    Ok(normalized)
}

async fn ensure_track_in_scope(
    pool: &PgPool,
    project_id: Uuid,
    script_id: Uuid,
    track_numeric_id: i32,
) -> Result<(), ApiError> {
    let exists: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1
          FROM app_video_track
          WHERE project_id = $1
            AND (script_id = $2 OR script_id IS NULL)
            AND numeric_id = $3
        )
        "#,
    )
    .bind(project_id)
    .bind(script_id)
    .bind(track_numeric_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if exists {
        Ok(())
    } else {
        Err(ApiError::NotFound)
    }
}

async fn ensure_storyboards_in_scope(
    pool: &PgPool,
    script_id: Uuid,
    storyboard_ids: &[i32],
) -> Result<(), ApiError> {
    let owned_ids = sqlx::query_scalar::<_, i32>(
        r#"
        SELECT numeric_id
        FROM app_storyboard
        WHERE script_id = $1
          AND numeric_id = ANY($2)
        "#,
    )
    .bind(script_id)
    .bind(storyboard_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if owned_ids.len() == storyboard_ids.len() {
        Ok(())
    } else {
        Err(ApiError::NotFound)
    }
}

async fn load_project_aspect_ratio(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<Option<String>, ApiError> {
    let raw = sqlx::query_scalar::<_, Option<String>>(
        "SELECT video_ratio FROM app_project WHERE id = $1",
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(raw.and_then(|value| compact_video_ratio(&value)))
}

fn compact_video_ratio(value: &str) -> Option<String> {
    let normalized = value.trim().to_ascii_lowercase();
    if normalized.is_empty() {
        return None;
    }
    if normalized.contains("9:16") {
        return Some("9:16".to_string());
    }
    if normalized.contains("1:1") || normalized.contains("square") {
        return Some("1:1".to_string());
    }
    if normalized.contains("16:9") || normalized.contains("horizontal") {
        return Some("16:9".to_string());
    }
    None
}

pub(crate) async fn load_auto_negative_prompt(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_ids: &[i32],
) -> Result<Option<String>, ApiError> {
    let prompts = load_auto_negative_prompt_details(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids,
    )
    .await?;
    Ok(storyboard_ids.iter().find_map(|storyboard_id| {
        prompts
            .get(storyboard_id)
            .and_then(|item| item.prompt.clone())
    }))
}

pub(crate) async fn load_auto_negative_prompts(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_ids: &[i32],
) -> Result<HashMap<i32, Option<String>>, ApiError> {
    Ok(load_auto_negative_prompt_details(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids,
    )
    .await?
    .into_iter()
    .map(|(storyboard_id, selection)| (storyboard_id, selection.prompt))
    .collect())
}

pub(crate) async fn load_auto_negative_prompt_details(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_ids: &[i32],
) -> Result<HashMap<i32, AutoNegativePromptSelection>, ApiError> {
    if storyboard_ids.is_empty() {
        return Ok(HashMap::new());
    }
    let review_row_limit = negative_review_fetch_limit(storyboard_ids.len());
    let rows = load_negative_review_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids,
        review_row_limit,
    )
    .await?;
    let rejected_rows = load_rejected_video_negative_memory_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids.len(),
    )
    .await?;
    let selected_rows = load_selected_video_memory_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids.len(),
    )
    .await?;
    let storyboard_seed_rows = load_storyboard_prompt_seed_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids,
    )
    .await?;

    Ok(build_storyboard_negative_prompts(
        storyboard_ids,
        &rows,
        &rejected_rows,
        &selected_rows,
        &storyboard_seed_rows,
    ))
}

pub(crate) async fn load_storyboard_negative_prompt_runtime(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_id: i32,
) -> Result<StoryboardNegativePromptRuntime, ApiError> {
    let review_rows = load_negative_review_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        &[storyboard_id],
        negative_review_fetch_limit(1),
    )
    .await?;
    let rejected_rows = load_rejected_video_negative_memory_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        1,
    )
    .await?;
    let selected_rows =
        load_selected_video_memory_rows(pool, user_id, project_numeric_id, script_numeric_id, 1)
            .await?;
    let storyboard_seed_rows = load_storyboard_prompt_seed_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        &[storyboard_id],
    )
    .await?;
    let mut contexts = build_storyboard_negative_prompt_contexts(
        &[storyboard_id],
        &review_rows,
        &selected_rows,
        storyboard_seed_rows,
    );
    let context =
        contexts
            .remove(&storyboard_id)
            .unwrap_or_else(|| StoryboardNegativePromptContext {
                storyboard_id,
                storyboard_review_rows: Vec::new(),
                selected_rows: selected_rows.clone(),
                storyboard_row: None,
                current_prompt_seed: None,
                subject_candidates: Vec::new(),
            });
    let (selection, pending_observation_candidates) =
        build_storyboard_negative_prompt_selection(&context, &rejected_rows);
    let prompt_support_rows =
        load_storyboard_prompt_support_rows(pool, user_id, project_numeric_id, script_numeric_id)
            .await?;

    Ok(StoryboardNegativePromptRuntime {
        storyboard_id,
        selection,
        pending_observation_candidates,
        rejected_rows,
        selected_rows,
        prompt_support_rows,
        storyboard_row: context.storyboard_row,
        current_prompt_seed: context.current_prompt_seed,
        subject_candidates: context.subject_candidates,
    })
}

async fn load_negative_review_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_ids: &[i32],
    review_row_limit: i64,
) -> Result<Vec<QualityReviewSeedRow>, ApiError> {
    let storyboard_target_ids = storyboard_ids
        .iter()
        .map(ToString::to_string)
        .collect::<Vec<_>>();
    sqlx::query_as::<_, QualityReviewSeedRow>(
        r#"
        SELECT target_type, target_id, bad_case_category, comments
        FROM app_quality_review
        WHERE user_id = $1
          AND project_id = $2
          AND (script_id IS NULL OR script_id = $3)
          AND (
            is_bad_case = TRUE
            OR passed = FALSE
            OR COALESCE(visual_quality, 10) <= 4
            OR COALESCE(overall_score, 10) <= 4
          )
          AND (
            target_type IN ('video', 'output')
            OR (target_type = 'storyboard' AND target_id = ANY($4))
          )
        ORDER BY
          CASE
            WHEN target_type = 'storyboard' AND target_id = ANY($4) THEN 0
            WHEN script_id = $3 THEN 1
            ELSE 2
          END,
          created_at DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(&storyboard_target_ids)
    .bind(review_row_limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

async fn load_storyboard_prompt_support_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<Vec<AgentMemoryRow>, ApiError> {
    sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND (
            (episodes_id = $3 AND name IN (
                'rejected_video_negative_memory',
                'selected_video_memory',
                'script_video_style_memory',
                'script_role_video_style_memory',
                'script_video_observation_memory',
                'script_role_video_observation_memory',
                'auto_scope_memory'
            ))
            OR (episodes_id IS NULL AND name IN (
                'project_video_style_memory',
                'project_role_video_style_memory',
                'project_video_observation_memory',
                'project_role_video_observation_memory'
            ))
          )
        ORDER BY create_time_ms DESC
        LIMIT 24
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

fn negative_review_fetch_limit(storyboard_count: usize) -> i64 {
    if storyboard_count == 0 {
        return VIDEO_NEGATIVE_REVIEW_BASE_LIMIT;
    }

    let storyboard_count = i64::try_from(storyboard_count).unwrap_or(i64::MAX);
    (VIDEO_NEGATIVE_REVIEW_BASE_LIMIT
        + storyboard_count.saturating_mul(VIDEO_NEGATIVE_REVIEW_PER_STORYBOARD_ROWS))
    .min(VIDEO_NEGATIVE_REVIEW_MAX_LIMIT)
}

async fn load_rejected_video_negative_memory_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_count: usize,
) -> Result<Vec<AgentMemoryRow>, ApiError> {
    let rejected_memory_row_limit = rejected_negative_memory_fetch_limit(storyboard_count);
    sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND (
            (episodes_id = $3 AND name IN (
                'rejected_video_negative_memory',
                'script_video_observation_memory',
                'script_role_video_observation_memory'
            ))
            OR (episodes_id IS NULL AND name IN (
                'project_video_observation_memory',
                'project_role_video_observation_memory'
            ))
          )
        ORDER BY create_time_ms DESC
        LIMIT $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(rejected_memory_row_limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

async fn load_storyboard_prompt_seed_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_ids: &[i32],
) -> Result<HashMap<i32, StoryboardPromptSeedRow>, ApiError> {
    let rows = sqlx::query_as::<_, (i32, Option<String>, Option<String>, Option<String>)>(
        r#"
        SELECT sb.numeric_id, sb.prompt, sb.video_desc, sb.duration
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND sc.numeric_id = $3
          AND sb.numeric_id = ANY($4)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(storyboard_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(rows
        .into_iter()
        .map(|(storyboard_id, prompt, video_desc, duration)| {
            (
                storyboard_id,
                StoryboardPromptSeedRow {
                    prompt,
                    video_desc,
                    duration,
                },
            )
        })
        .collect())
}

async fn load_selected_video_memory_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_count: usize,
) -> Result<Vec<AgentMemoryRow>, ApiError> {
    let selected_memory_row_limit = selected_memory_fetch_limit(storyboard_count);
    sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND (
            (episodes_id = $3 AND name IN (
                'selected_video_memory',
                'script_video_style_memory',
                'script_role_video_style_memory'
            ))
            OR (episodes_id IS NULL AND name IN (
                'project_video_style_memory',
                'project_role_video_style_memory'
            ))
          )
        ORDER BY create_time_ms DESC
        LIMIT $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(selected_memory_row_limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

fn rejected_negative_memory_fetch_limit(storyboard_count: usize) -> i64 {
    if storyboard_count == 0 {
        return VIDEO_NEGATIVE_REJECTED_MEMORY_BASE_LIMIT;
    }

    let storyboard_count = i64::try_from(storyboard_count).unwrap_or(i64::MAX);
    (VIDEO_NEGATIVE_REJECTED_MEMORY_BASE_LIMIT
        .max(storyboard_count.saturating_mul(VIDEO_NEGATIVE_REJECTED_MEMORY_PER_STORYBOARD_ROWS)))
    .min(VIDEO_NEGATIVE_REJECTED_MEMORY_MAX_LIMIT)
}

fn selected_memory_fetch_limit(storyboard_count: usize) -> i64 {
    if storyboard_count == 0 {
        return VIDEO_NEGATIVE_SELECTED_MEMORY_BASE_LIMIT;
    }

    let storyboard_count = i64::try_from(storyboard_count).unwrap_or(i64::MAX);
    (VIDEO_NEGATIVE_SELECTED_MEMORY_BASE_LIMIT.max(
        storyboard_count
            .saturating_mul(VIDEO_NEGATIVE_SELECTED_MEMORY_PER_STORYBOARD_ROWS)
            .saturating_add(VIDEO_NEGATIVE_SELECTED_MEMORY_SUMMARY_ROWS),
    ))
    .min(VIDEO_NEGATIVE_SELECTED_MEMORY_MAX_LIMIT)
}

fn filter_selected_rows_for_subject(
    selected_rows: &[AgentMemoryRow],
    subject_candidates: &[String],
) -> Vec<AgentMemoryRow> {
    if subject_candidates.is_empty() {
        return selected_rows
            .iter()
            .map(|row| AgentMemoryRow {
                name: row.name.clone(),
                content: row.content.clone(),
            })
            .collect();
    }

    let normalized_candidates = subject_candidates
        .iter()
        .map(|candidate| normalize_prompt_text(candidate))
        .filter(|candidate| !candidate.is_empty())
        .collect::<Vec<_>>();
    selected_rows
        .iter()
        .filter(|row| {
            if row.name != "selected_video_memory" {
                return true;
            }
            let Some(subject) = extract_key_value(&row.content, "subject")
                .or_else(|| extract_key_value(&row.content, "subjectAliases"))
            else {
                return true;
            };
            let memory_subjects = subject
                .split('/')
                .map(normalize_prompt_text)
                .filter(|subject| !subject.is_empty())
                .collect::<Vec<_>>();
            memory_subjects.is_empty()
                || memory_subjects.iter().any(|memory_subject| {
                    normalized_candidates.iter().any(|candidate| {
                        candidate == memory_subject
                            || candidate.contains(memory_subject)
                            || memory_subject.contains(candidate)
                    })
                })
        })
        .map(|row| AgentMemoryRow {
            name: row.name.clone(),
            content: row.content.clone(),
        })
        .collect()
}

fn build_storyboard_negative_prompts(
    storyboard_ids: &[i32],
    review_rows: &[QualityReviewSeedRow],
    rejected_rows: &[AgentMemoryRow],
    selected_rows: &[AgentMemoryRow],
    storyboard_seed_rows: &HashMap<i32, StoryboardPromptSeedRow>,
) -> HashMap<i32, AutoNegativePromptSelection> {
    let contexts = build_storyboard_negative_prompt_contexts(
        storyboard_ids,
        review_rows,
        selected_rows,
        storyboard_seed_rows.clone(),
    );

    storyboard_ids
        .iter()
        .copied()
        .map(|storyboard_id| {
            let selection = contexts
                .get(&storyboard_id)
                .map(|context| build_storyboard_negative_prompt_selection(context, rejected_rows).0)
                .unwrap_or_else(|| {
                    build_storyboard_negative_prompt_selection(
                        &StoryboardNegativePromptContext {
                            storyboard_id,
                            storyboard_review_rows: Vec::new(),
                            selected_rows: selected_rows.to_vec(),
                            storyboard_row: None,
                            current_prompt_seed: None,
                            subject_candidates: Vec::new(),
                        },
                        rejected_rows,
                    )
                    .0
                });
            (storyboard_id, selection)
        })
        .collect()
}

fn build_storyboard_negative_prompt_contexts(
    storyboard_ids: &[i32],
    review_rows: &[QualityReviewSeedRow],
    selected_rows: &[AgentMemoryRow],
    mut storyboard_seed_rows: HashMap<i32, StoryboardPromptSeedRow>,
) -> HashMap<i32, StoryboardNegativePromptContext> {
    let mut storyboard_review_rows = storyboard_ids
        .iter()
        .copied()
        .map(|storyboard_id| (storyboard_id, Vec::new()))
        .collect::<HashMap<_, _>>();
    let global_review_rows = review_rows
        .iter()
        .filter(|row| quality_review_storyboard_target_id(row).is_none())
        .cloned()
        .collect::<Vec<_>>();
    for row in review_rows {
        if let Some(storyboard_id) = quality_review_storyboard_target_id(row) {
            if let Some(group) = storyboard_review_rows.get_mut(&storyboard_id) {
                group.push(row.clone());
            }
        }
    }

    storyboard_ids
        .iter()
        .copied()
        .map(|storyboard_id| {
            let storyboard_row = storyboard_seed_rows.remove(&storyboard_id);
            let current_prompt_seed = storyboard_row.as_ref().and_then(storyboard_prompt_seed);
            let subject_candidates = storyboard_row
                .as_ref()
                .and_then(|row| row.video_desc.as_deref())
                .and_then(parse_structured_storyboard_description)
                .map(|fields| {
                    selected_memory_subject_aliases(&fields.subject, &fields.subject_refs)
                })
                .unwrap_or_default();
            let storyboard_selected_rows =
                filter_selected_rows_for_subject(selected_rows, &subject_candidates);
            let review_rows = storyboard_review_rows
                .remove(&storyboard_id)
                .unwrap_or_default()
                .into_iter()
                .chain(global_review_rows.iter().cloned())
                .collect::<Vec<_>>();
            (
                storyboard_id,
                StoryboardNegativePromptContext {
                    storyboard_id,
                    storyboard_review_rows: review_rows,
                    selected_rows: storyboard_selected_rows,
                    storyboard_row,
                    current_prompt_seed,
                    subject_candidates,
                },
            )
        })
        .collect()
}

fn build_storyboard_negative_prompt_selection(
    context: &StoryboardNegativePromptContext,
    rejected_rows: &[AgentMemoryRow],
) -> (AutoNegativePromptSelection, Vec<String>) {
    let selected_style_note = select_selected_video_memory_notes(
        &context.selected_rows,
        context.storyboard_id,
        context.current_prompt_seed.as_deref(),
    )
    .into_iter()
    .next();
    let prioritized_style_note = resolve_negative_filter_style_note(
        &context.selected_rows,
        context.storyboard_id,
        context.current_prompt_seed.as_deref(),
        context.storyboard_row.as_ref(),
        selected_style_note,
        &context.subject_candidates,
    );
    let review_fragments = filter_conflicting_review_fragments(
        collect_negative_review_fragments(&context.storyboard_review_rows, context.storyboard_id),
        prioritized_style_note.as_deref(),
        context.storyboard_row.as_ref(),
    );
    let rejected_memory_selection =
        select_rejected_video_memory_notes_and_observation_candidates_for_subject(
            rejected_rows,
            context.storyboard_id,
            context.current_prompt_seed.as_deref(),
            &context.subject_candidates,
            context.storyboard_row.as_ref(),
        );
    let negative_memory_notes = rejected_memory_selection.negative_notes;
    let pending_observation_candidates = rejected_memory_selection.observation_notes;
    let rejected_fragments = filter_conflicting_review_fragments(
        split_negative_prompt_fragments(negative_memory_notes.into_iter().next().as_deref()),
        prioritized_style_note.as_deref(),
        context.storyboard_row.as_ref(),
    );
    let review_fragments =
        prune_storyboard_negative_fragments(review_fragments, context.storyboard_row.as_ref());
    let rejected_fragments =
        prune_storyboard_negative_fragments(rejected_fragments, context.storyboard_row.as_ref());
    let review_fragments =
        compact_review_fragments_against_rejected_memory(review_fragments, &rejected_fragments);
    let rejected_fragments = compact_rejected_fragments_against_review_focus(
        rejected_fragments,
        &review_fragments,
        context.storyboard_row.as_ref(),
    );
    let observation_fragments = if rejected_fragments.is_empty() && review_fragments.is_empty() {
        build_storyboard_observation_negative_fragments(
            pending_observation_candidates.clone(),
            prioritized_style_note.as_deref(),
            context.storyboard_row.as_ref(),
        )
    } else {
        Vec::new()
    };
    let effective_rejected_fragments =
        if rejected_fragments.is_empty() && review_fragments.is_empty() {
            observation_fragments.clone()
        } else {
            rejected_fragments.clone()
        };
    let budget_tier = resolve_negative_prompt_budget_tier(
        context.storyboard_row.as_ref(),
        &context.storyboard_review_rows,
        &effective_rejected_fragments,
        &review_fragments,
        context.subject_candidates.len(),
    );
    let review_fragment_count = review_fragments.len();
    let rejected_memory_fragment_count = effective_rejected_fragments.len();
    let used_pending_observation_fallback = rejected_fragments.is_empty()
        && review_fragments.is_empty()
        && !observation_fragments.is_empty();
    let prompt = merge_prioritized_negative_prompt_fragment_groups(
        &[effective_rejected_fragments, review_fragments],
        budget_tier,
    );
    let fragment_count = prompt
        .as_deref()
        .map(|value| split_negative_prompt_fragments(Some(value)).len())
        .unwrap_or(0);

    (
        AutoNegativePromptSelection {
            prompt,
            fragment_count,
            budget_tier: budget_tier.as_str(),
            review_fragment_count,
            rejected_memory_fragment_count,
            used_pending_observation_fallback,
        },
        pending_observation_candidates,
    )
}

fn build_storyboard_observation_negative_fragments(
    observation_fragments: Vec<String>,
    prioritized_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let observation_fragments = filter_conflicting_review_fragments(
        observation_fragments,
        prioritized_style_note,
        storyboard_row,
    );
    prune_storyboard_negative_fragments(observation_fragments, storyboard_row)
}

fn resolve_negative_prompt_budget_tier(
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    storyboard_review_rows: &[QualityReviewSeedRow],
    rejected_fragments: &[String],
    review_fragments: &[String],
    subject_alias_count: usize,
) -> VideoNegativePromptBudgetTier {
    let mut risk_score = 0;
    if subject_aliases_need_expanded_negative_budget(
        subject_alias_count,
        rejected_fragments,
        review_fragments,
    ) {
        risk_score += 1;
    }
    if storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
        .is_some_and(|fields| negative_prompt_scene_needs_expanded_budget(&fields))
    {
        risk_score += 1;
    }
    if !storyboard_review_rows.is_empty() {
        risk_score += 1;
    }
    if rejected_fragments.len() >= 2 {
        risk_score += 1;
    }
    if review_fragments
        .iter()
        .chain(rejected_fragments.iter())
        .any(|fragment| negative_fragment_requires_strict_continuity_budget(fragment))
    {
        risk_score += 1;
    }

    if risk_score >= 2 {
        VideoNegativePromptBudgetTier::Expanded
    } else {
        VideoNegativePromptBudgetTier::Lean
    }
}

fn subject_aliases_need_expanded_negative_budget(
    _subject_alias_count: usize,
    rejected_fragments: &[String],
    review_fragments: &[String],
) -> bool {
    review_fragments
        .iter()
        .chain(rejected_fragments.iter())
        .any(|fragment| negative_fragment_targets_identity_consistency(fragment))
}

fn negative_fragment_targets_identity_consistency(fragment: &str) -> bool {
    let canonical = canonical_negative_fragment(fragment);
    canonical.contains("face")
        || canonical.contains("identity")
        || canonical.contains("costume")
        || canonical.contains("character")
}

fn negative_prompt_scene_needs_expanded_budget(fields: &StructuredStoryboardDescription) -> bool {
    [
        fields.mood.as_str(),
        fields.action.as_str(),
        fields.dialogue.as_str(),
        fields.camera_move.as_str(),
        fields.shot.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        [
            "哭", "泪", "怒", "吼", "崩溃", "压迫", "紧张", "慌", "急", "追", "跑", "冲", "喊",
            "颤", "手持", "handheld", "近景", "特写",
        ]
        .iter()
        .any(|keyword| value.contains(keyword))
    })
}

fn prune_storyboard_negative_fragments(
    fragments: Vec<String>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let mut kept = fragments
        .into_iter()
        .filter_map(|fragment| {
            compact_negative_fragment_against_storyboard_risk(&fragment, storyboard_row)
        })
        .filter(|fragment| negative_fragment_matches_storyboard_risk(fragment, storyboard_row))
        .collect::<Vec<_>>();
    kept.dedup();
    kept
}

fn compact_negative_fragment_against_storyboard_risk(
    fragment: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let trimmed = fragment.trim();
    if trimmed.is_empty() {
        return None;
    }

    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return Some(trimmed.to_string());
    };

    match canonical_negative_fragment(trimmed).as_str() {
        "avoid extra shot changes or wrong framing" => {
            let has_shot_change_risk = negative_prompt_scene_has_shot_change_risk(&fields);
            let has_extreme_angle_risk = negative_prompt_scene_has_extreme_angle_risk(&fields);
            let has_tight_close_up_risk = negative_prompt_scene_has_tight_close_up_risk(&fields);
            match (
                has_shot_change_risk,
                has_extreme_angle_risk,
                has_tight_close_up_risk,
            ) {
                (true, true, true) => Some(trimmed.to_string()),
                (true, true, false) => {
                    Some("avoid unnecessary shot changes, avoid extreme camera angle".to_string())
                }
                (true, false, true) => Some(
                    "avoid unnecessary shot changes, avoid overly tight close-up framing"
                        .to_string(),
                ),
                (true, false, false) => Some("avoid unnecessary shot changes".to_string()),
                (false, true, true) => {
                    Some("avoid extreme camera angle or overly tight close-up framing".to_string())
                }
                (false, true, false) => Some("avoid extreme camera angle".to_string()),
                (false, false, true) => Some("avoid overly tight close-up framing".to_string()),
                (false, false, false) => Some("avoid unnecessary shot changes".to_string()),
            }
        }
        "avoid warped anatomy, blur, flicker" => {
            if negative_prompt_scene_has_motion_risk(&fields) {
                Some(trimmed.to_string())
            } else {
                Some("avoid warped anatomy or blur".to_string())
            }
        }
        "avoid flat cold lighting or harsh backlight silhouette" => {
            let has_flat_cold_lighting = negative_prompt_scene_has_flat_cold_lighting_risk(&fields);
            let has_backlight = negative_prompt_scene_has_backlight_silhouette_risk(&fields);
            let has_neon_reflections = negative_prompt_scene_has_neon_reflection_risk(&fields);
            match (has_flat_cold_lighting, has_backlight) {
                (true, true) => Some(trimmed.to_string()),
                (true, false) => Some("avoid flat cold lighting".to_string()),
                (false, true) => Some("avoid harsh backlight silhouette".to_string()),
                (false, false) if has_neon_reflections => {
                    Some("avoid distracting neon reflections".to_string())
                }
                (false, false) => {
                    negative_prompt_scene_has_lighting_risk(&fields).then_some(trimmed.to_string())
                }
            }
        }
        "avoid oppressive or frantic mood" | "avoid overly cold, oppressive, or frantic mood" => {
            if negative_prompt_scene_intends_frantic_mood(&fields) {
                None
            } else if negative_prompt_scene_prefers_restrained_emotional_guard(&fields) {
                Some("avoid frantic mood".to_string())
            } else {
                Some(trimmed.to_string())
            }
        }
        "avoid blank expression or monotone delivery" => {
            negative_prompt_scene_needs_expressive_performance_guard(&fields)
                .then_some(trimmed.to_string())
        }
        _ => Some(trimmed.to_string()),
    }
}

fn negative_fragment_matches_storyboard_risk(
    fragment: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return true;
    };

    match negative_fragment_family(fragment) {
        "shot_change_only" => true,
        "lip_sync_mismatch" => !storyboard_dialogue_is_empty(&fields.dialogue),
        "lighting_backlight" => negative_prompt_scene_has_lighting_risk(&fields),
        "rushed_motion" => true,
        "mood_tone" => negative_prompt_scene_needs_emotional_memory(&fields),
        "performance_delivery" => negative_prompt_scene_needs_expressive_performance_guard(&fields),
        "camera_framing" | "shot_change_framing" => negative_prompt_scene_has_framing_risk(&fields),
        _ => true,
    }
}

fn negative_prompt_scene_has_motion_risk(fields: &StructuredStoryboardDescription) -> bool {
    [
        fields.shot.as_str(),
        fields.camera_move.as_str(),
        fields.action.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "跟拍", "推进", "拉远", "摇镜", "手持", "奔跑", "跑", "冲", "扑", "追", "快步",
                "转身", "踉跄", "急退", "handheld", "push in", "whip",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn negative_prompt_scene_has_lighting_risk(fields: &StructuredStoryboardDescription) -> bool {
    negative_prompt_scene_has_backlight_silhouette_risk(fields)
        || negative_prompt_scene_has_flat_cold_lighting_risk(fields)
        || negative_prompt_scene_has_neon_reflection_risk(fields)
}

fn negative_prompt_scene_has_neon_reflection_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.setting.as_str(),
        fields.lighting.as_str(),
        fields.sound.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "霓虹",
                "反光",
                "玻璃",
                "雨",
                "reflection",
                "wet street",
                "headlight reflection",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn negative_prompt_scene_has_backlight_silhouette_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.setting.as_str(),
        fields.lighting.as_str(),
        fields.sound.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && ["逆光", "背光", "剪影", "车灯", "silhouette", "backlight"]
                .iter()
                .any(|keyword| value.contains(keyword))
    })
}

fn negative_prompt_scene_has_flat_cold_lighting_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.setting.as_str(),
        fields.lighting.as_str(),
        fields.sound.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "冷光",
                "冷调",
                "阴天",
                "曝光",
                "flat lighting",
                "cold lighting",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn negative_prompt_scene_has_framing_risk(fields: &StructuredStoryboardDescription) -> bool {
    negative_prompt_scene_has_extreme_angle_risk(fields)
        || negative_prompt_scene_has_tight_close_up_risk(fields)
        || negative_prompt_scene_has_shot_change_risk(fields)
}

fn negative_prompt_scene_has_shot_change_risk(fields: &StructuredStoryboardDescription) -> bool {
    [
        fields.shot.as_str(),
        fields.camera_move.as_str(),
        fields.action.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "跟拍",
                "推进",
                "拉远",
                "摇镜",
                "甩镜",
                "切换",
                "转场",
                "追",
                "跑",
                "冲",
                "手持",
                "follow",
                "push in",
                "pull back",
                "whip",
                "pan",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn negative_prompt_scene_has_extreme_angle_risk(fields: &StructuredStoryboardDescription) -> bool {
    [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .map(normalize_prompt_text)
        .any(|value| {
            !value.is_empty()
                && [
                    "仰拍",
                    "俯拍",
                    "倾斜",
                    "low angle",
                    "high angle",
                    "dutch angle",
                ]
                .iter()
                .any(|keyword| value.contains(keyword))
        })
}

fn negative_prompt_scene_has_tight_close_up_risk(fields: &StructuredStoryboardDescription) -> bool {
    [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .map(normalize_prompt_text)
        .any(|value| {
            !value.is_empty()
                && ["近景", "特写", "close-up", "tight close-up"]
                    .iter()
                    .any(|keyword| value.contains(keyword))
        })
}

fn negative_prompt_scene_needs_emotional_memory(fields: &StructuredStoryboardDescription) -> bool {
    [
        fields.mood.as_str(),
        fields.action.as_str(),
        fields.dialogue.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "哭",
                "泪",
                "哽咽",
                "颤",
                "停顿",
                "压抑",
                "克制",
                "愤怒",
                "惊慌",
                "紧张",
                "压迫",
                "冷峻",
                "崩溃",
                "隐忍",
                "欲言又止",
                "迟疑",
                "回头",
                "犹豫",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn negative_prompt_scene_needs_expressive_performance_guard(
    fields: &StructuredStoryboardDescription,
) -> bool {
    if !negative_prompt_scene_needs_emotional_memory(fields) {
        return false;
    }

    if !storyboard_dialogue_is_empty(&fields.dialogue) {
        return true;
    }

    [fields.mood.as_str(), fields.action.as_str()]
        .into_iter()
        .map(normalize_prompt_text)
        .any(|value| {
            !value.is_empty()
                && [
                    "欲言又止",
                    "隐忍",
                    "哽咽",
                    "低声",
                    "轻声",
                    "迟疑",
                    "停顿",
                    "犹豫",
                    "强忍",
                    "颤",
                ]
                .iter()
                .any(|keyword| value.contains(keyword))
        })
}

fn negative_prompt_scene_prefers_restrained_emotional_guard(
    fields: &StructuredStoryboardDescription,
) -> bool {
    let restrained = [
        fields.mood.as_str(),
        fields.action.as_str(),
        fields.dialogue.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "克制",
                "隐忍",
                "欲言又止",
                "迟疑",
                "犹豫",
                "哽咽",
                "停顿",
                "低声",
                "轻声",
                "压低声音",
                "忍住",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    });
    let intended_cold_or_oppressive = [fields.mood.as_str(), fields.lighting.as_str()]
        .into_iter()
        .map(normalize_prompt_text)
        .any(|value| {
            !value.is_empty()
                && ["压迫", "紧张", "冷峻", "冷调", "冷色", "冷光"]
                    .iter()
                    .any(|keyword| value.contains(keyword))
        });
    restrained
        && !intended_cold_or_oppressive
        && !negative_prompt_scene_intends_frantic_mood(fields)
}

fn negative_prompt_scene_intends_frantic_mood(fields: &StructuredStoryboardDescription) -> bool {
    [
        fields.mood.as_str(),
        fields.action.as_str(),
        fields.dialogue.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "惊慌",
                "崩溃",
                "失控",
                "慌乱",
                "怒吼",
                "狂奔",
                "冲出",
                "扑过去",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn negative_fragment_requires_strict_continuity_budget(fragment: &str) -> bool {
    let canonical = canonical_negative_fragment(fragment);
    canonical.contains("face")
        || canonical.contains("identity")
        || canonical.contains("costume")
        || canonical.contains("warped")
        || canonical.contains("anatom")
        || canonical.contains("lip-sync")
        || canonical.contains("shot changes")
        || canonical.contains("wrong framing")
}

fn resolve_negative_filter_style_note(
    selected_rows: &[AgentMemoryRow],
    storyboard_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    selected_style_note: Option<String>,
    subject_candidates: &[String],
) -> Option<String> {
    let role_style_note = select_subject_role_video_style_memory_notes_for_storyboard(
        selected_rows,
        subject_candidates,
        storyboard_row,
    )
    .into_iter()
    .find(|note| !note.is_empty());
    let exact_style_note = selected_style_note.filter(|note| {
        !negative_filter_exact_style_note_should_yield_to_role_memory(
            note,
            role_style_note.as_deref(),
        )
    });

    exact_style_note
        .or(role_style_note)
        .or_else(|| {
            select_prioritized_video_style_note(
                selected_rows,
                storyboard_id,
                current_prompt_seed,
                storyboard_row,
            )
            .and_then(|note| compact_contextual_negative_style_note(&note, storyboard_row))
        })
        .or_else(|| {
            select_contextual_summary_style_note(selected_rows, storyboard_row, subject_candidates)
        })
}

fn negative_filter_exact_style_note_should_yield_to_role_memory(
    exact_note: &str,
    role_style_note: Option<&str>,
) -> bool {
    role_style_note.is_some()
        && negative_filter_exact_style_note_is_low_signal_local_camera(exact_note)
}

fn negative_filter_exact_style_note_is_low_signal_local_camera(note: &str) -> bool {
    let fragments = split_prompt_note_fragments(note).collect::<Vec<_>>();
    !fragments.is_empty()
        && fragments
            .iter()
            .all(|fragment| negative_filter_low_signal_local_camera_style_fragment(fragment))
}

fn negative_filter_low_signal_local_camera_style_fragment(fragment: &str) -> bool {
    if !fragment.starts_with("镜头") {
        return false;
    }

    let body = normalize_prompt_text(fragment.trim_start_matches("镜头"));
    if body.is_empty() {
        return false;
    }
    if [
        "压迫", "冷峻", "紧张", "逆光", "光影", "情绪", "表演", "语气", "环境", "声场", "雨丝",
        "霓虹", "停顿", "哽咽",
    ]
    .iter()
    .any(|keyword| body.contains(keyword))
    {
        return false;
    }

    [
        "稳定",
        "稳定跟拍",
        "跟拍",
        "近景稳定",
        "中景稳定",
        "远景稳定",
        "特写稳定",
        "全景稳定",
        "近景",
        "中景",
        "远景",
        "特写",
        "全景",
    ]
    .iter()
    .any(|candidate| body == *candidate)
}

fn select_contextual_summary_style_note(
    selected_rows: &[AgentMemoryRow],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    subject_candidates: &[String],
) -> Option<String> {
    let context = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)?;

    select_subject_role_video_style_memory_notes_for_storyboard(
        selected_rows,
        subject_candidates,
        storyboard_row,
    )
    .into_iter()
    .chain(select_script_video_style_memory_notes_for_storyboard(
        selected_rows,
        storyboard_row,
    ))
    .chain(select_project_video_style_memory_notes_for_storyboard(
        selected_rows,
        storyboard_row,
    ))
    .filter_map(|note| {
        let evidence = style_note_context_evidence(&note, &context);
        let compacted = compact_contextual_negative_style_note(&note, storyboard_row)?;
        (evidence >= 2).then_some((evidence, compacted))
    })
    .max_by(|(left_evidence, left_note), (right_evidence, right_note)| {
        left_evidence
            .cmp(right_evidence)
            .then_with(|| right_note.chars().count().cmp(&left_note.chars().count()))
    })
    .map(|(_, note)| note)
}

fn compact_contextual_negative_style_note(
    note: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return None;
    }
    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return compact_video_style_prompt_note(&normalized);
    };

    let expected_camera = [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .filter(|part| !part.is_empty())
        .collect::<String>();
    let fragments = split_prompt_note_fragments(&normalized)
        .filter(|fragment| !fragment.is_empty())
        .filter(|fragment| {
            negative_style_fragment_matches_storyboard(fragment, &fields, &expected_camera)
        })
        .filter_map(|fragment| trim_negative_style_fragment_against_storyboard(&fragment, &fields))
        .map(|fragment| clip_prompt_fragment(&fragment, 56))
        .collect::<Vec<_>>();
    if fragments.is_empty() {
        return None;
    }

    Some(clip_prompt_fragment(&fragments.join("，"), 56))
}

fn negative_style_fragment_matches_storyboard(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
    expected_camera: &str,
) -> bool {
    if fragment.starts_with("镜头") {
        return negative_style_fragment_overlaps_field(fragment, &fields.shot, expected_camera)
            || negative_style_fragment_overlaps_field(
                fragment,
                &fields.camera_move,
                expected_camera,
            );
    }
    if fragment.starts_with("情绪") {
        return negative_style_fragment_overlaps_field(fragment, &fields.mood, expected_camera);
    }
    if fragment.starts_with("光影") {
        return negative_style_fragment_overlaps_field(fragment, &fields.lighting, expected_camera);
    }
    false
}

fn trim_negative_style_fragment_against_storyboard(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> Option<String> {
    if fragment.starts_with("镜头") {
        return trim_negative_style_fragment_prefix(
            fragment,
            "镜头",
            &[fields.shot.as_str(), fields.camera_move.as_str()],
        );
    }
    if fragment.starts_with("情绪") {
        return trim_negative_style_fragment_prefix(fragment, "情绪", &[fields.mood.as_str()]);
    }
    if fragment.starts_with("光影") {
        return trim_negative_style_fragment_prefix(fragment, "光影", &[fields.lighting.as_str()]);
    }
    Some(fragment.to_string())
}

fn trim_negative_style_fragment_prefix(
    fragment: &str,
    prefix: &str,
    fields: &[&str],
) -> Option<String> {
    let body = fragment.strip_prefix(prefix).unwrap_or(fragment);
    let mut residual = normalize_prompt_text(body);
    for field in fields {
        let normalized_field = normalize_prompt_text(field);
        if normalized_field.is_empty() {
            continue;
        }
        if residual == normalized_field {
            return None;
        }
        residual = residual.replace(&normalized_field, "");
    }
    let residual = normalize_prompt_text(&residual);
    if residual.is_empty() {
        None
    } else {
        Some(format!("{prefix}{residual}"))
    }
}

fn negative_style_fragment_overlaps_field(
    fragment: &str,
    field: &str,
    expected_camera: &str,
) -> bool {
    let normalized_field = normalize_prompt_text(field);
    if normalized_field.is_empty() {
        return false;
    }
    let canonical = canonical_negative_style_fragment(fragment);
    !canonical.is_empty()
        && (canonical == normalized_field
            || canonical.contains(&normalized_field)
            || normalized_field.contains(&canonical)
            || (!expected_camera.is_empty()
                && canonical == expected_camera
                && (expected_camera.contains(&normalized_field)
                    || normalized_field.contains(expected_camera))))
}

fn canonical_negative_style_fragment(fragment: &str) -> String {
    normalize_prompt_text(
        fragment
            .strip_prefix("镜头")
            .or_else(|| fragment.strip_prefix("情绪"))
            .or_else(|| fragment.strip_prefix("光影"))
            .unwrap_or(fragment),
    )
}

fn style_note_context_evidence(
    style_note: &str,
    context: &StructuredStoryboardDescription,
) -> usize {
    let note = normalize_prompt_text(style_note);
    let mut evidence = 0usize;

    let mood = normalize_prompt_text(&context.mood);
    if !mood.is_empty() && note.contains(&mood) {
        evidence += 1;
    }

    let lighting = normalize_prompt_text(&context.lighting);
    if !lighting.is_empty() && note.contains(&lighting) {
        evidence += 1;
    }

    let shot = normalize_prompt_text(&context.shot);
    let camera_move = normalize_prompt_text(&context.camera_move);
    if (!shot.is_empty() && note.contains(&shot))
        || (!camera_move.is_empty() && note.contains(&camera_move))
    {
        evidence += 1;
    }

    evidence
}

fn filter_conflicting_review_fragments(
    fragments: Vec<String>,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    fragments
        .into_iter()
        .flat_map(|fragment| {
            compact_negative_constraint_fragments_against_storyboard_style(
                &fragment,
                selected_style_note,
                storyboard_row,
            )
        })
        .filter(|fragment| !review_fragment_is_irrelevant_to_storyboard(fragment, storyboard_row))
        .collect()
}

fn compact_review_fragments_against_rejected_memory(
    review_fragments: Vec<String>,
    rejected_fragments: &[String],
) -> Vec<String> {
    review_fragments
        .into_iter()
        .filter_map(|fragment| {
            compact_review_fragment_against_rejected_memory(&fragment, rejected_fragments)
        })
        .collect()
}

fn compact_rejected_fragments_against_review_focus(
    rejected_fragments: Vec<String>,
    review_fragments: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return rejected_fragments;
    };
    if !negative_prompt_scene_prefers_restrained_emotional_guard(&fields) {
        return rejected_fragments;
    }
    let review_has_performance_guard = review_fragments
        .iter()
        .any(|fragment| negative_fragment_family(fragment) == "performance_delivery");
    if !review_has_performance_guard {
        return rejected_fragments;
    }

    rejected_fragments
        .into_iter()
        .filter(|fragment| canonical_negative_fragment(fragment) != "avoid frantic mood")
        .collect()
}

fn compact_review_fragment_against_rejected_memory(
    fragment: &str,
    rejected_fragments: &[String],
) -> Option<String> {
    let trimmed = fragment.trim();
    if trimmed.is_empty() {
        return None;
    }
    let covered = |value: &str| negative_fragment_is_covered(value, rejected_fragments);
    match canonical_negative_fragment(trimmed).as_str() {
        "avoid extra shot changes or wrong framing" => compact_rejected_overlap_pair(
            trimmed,
            "avoid unnecessary shot changes",
            "avoid extreme camera angle or overly tight close-up framing",
            covered,
        ),
        "avoid rushed or jerky motion" => compact_rejected_overlap_pair(
            trimmed,
            "avoid rushed motion",
            "avoid flicker or motion jitter",
            covered,
        ),
        _ => (!covered(trimmed)).then_some(trimmed.to_string()),
    }
}

fn compact_rejected_overlap_pair(
    original: &str,
    lhs: &str,
    rhs: &str,
    covered: impl Fn(&str) -> bool,
) -> Option<String> {
    let lhs_covered = covered(lhs);
    let rhs_covered = covered(rhs);
    match (lhs_covered, rhs_covered) {
        (false, false) => Some(original.to_string()),
        (true, false) => Some(rhs.to_string()),
        (false, true) => Some(lhs.to_string()),
        (true, true) => None,
    }
}

fn review_fragment_conflicts_with_selected_style(
    fragment: &str,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    negative_constraint_conflicts_with_storyboard_style(
        &canonical_negative_fragment(fragment),
        selected_style_note,
        storyboard_row,
    )
}

fn review_fragment_is_irrelevant_to_storyboard(
    fragment: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    matches!(negative_fragment_family(fragment), "lip_sync_mismatch")
        && storyboard_row.is_some_and(storyboard_has_no_dialogue)
}

fn storyboard_has_no_dialogue(row: &StoryboardPromptSeedRow) -> bool {
    row.video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .is_some_and(|fields| storyboard_dialogue_is_empty(&fields.dialogue))
}

fn storyboard_dialogue_is_empty(dialogue: &str) -> bool {
    let normalized = normalize_prompt_text(dialogue);
    let normalized_ascii = normalized.to_ascii_lowercase();
    normalized.is_empty()
        || [
            "无台词",
            "无对白",
            "无旁白",
            "无语音",
            "no dialogue",
            "no voice-over",
            "silent",
        ]
        .iter()
        .map(|marker| normalize_prompt_text(marker).to_ascii_lowercase())
        .any(|marker| normalized_ascii == marker)
}

fn compact_negative_constraint_against_storyboard_style(
    fragment: &str,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let compacted = compact_negative_constraint_fragments_against_storyboard_style(
        fragment,
        selected_style_note,
        storyboard_row,
    );
    match compacted.len() {
        0 => None,
        1 => compacted.into_iter().next(),
        _ => Some(compacted.join(", ")),
    }
}

fn compact_negative_constraint_fragments_against_storyboard_style(
    fragment: &str,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let trimmed = fragment.trim();
    if trimmed.is_empty() {
        return Vec::new();
    }
    let conflicts = |value: &str| {
        negative_constraint_conflicts_with_storyboard_style(
            value.trim(),
            selected_style_note,
            storyboard_row,
        )
    };
    match canonical_negative_fragment(trimmed).as_str() {
        "avoid extreme camera angle or overly tight close-up framing" => {
            compact_conflicting_negative_pair(
                trimmed,
                "avoid extreme camera angle",
                "avoid overly tight close-up framing",
                conflicts,
            )
            .into_iter()
            .collect()
        }
        "avoid oppressive or frantic mood" | "avoid overly cold, oppressive, or frantic mood" => {
            compact_conflicting_mood_constraints(trimmed, conflicts)
        }
        "avoid flat cold lighting or harsh backlight silhouette" => {
            compact_conflicting_negative_pair(
                trimmed,
                "avoid flat cold lighting",
                "avoid harsh backlight silhouette",
                conflicts,
            )
            .into_iter()
            .collect()
        }
        "avoid distracting neon reflections" => (!conflicts(trimmed))
            .then_some(trimmed.to_string())
            .into_iter()
            .collect(),
        _ => (!conflicts(trimmed))
            .then_some(trimmed.to_string())
            .into_iter()
            .collect(),
    }
}

fn compact_conflicting_negative_pair(
    original: &str,
    lhs: &str,
    rhs: &str,
    conflicts: impl Fn(&str) -> bool,
) -> Option<String> {
    let lhs_conflicts = conflicts(lhs);
    let rhs_conflicts = conflicts(rhs);
    match (lhs_conflicts, rhs_conflicts) {
        (false, false) => Some(original.to_string()),
        (true, false) => Some(rhs.to_string()),
        (false, true) => Some(lhs.to_string()),
        (true, true) => None,
    }
}

fn compact_conflicting_mood_constraints(
    original: &str,
    conflicts: impl Fn(&str) -> bool,
) -> Vec<String> {
    let canonical = canonical_negative_fragment(original);
    let (allow_oppressive, allow_frantic, allow_cold) = match canonical.as_str() {
        "avoid oppressive or frantic mood" => (true, true, false),
        "avoid overly cold, oppressive, or frantic mood" => (true, true, true),
        "avoid oppressive mood" => (true, false, false),
        "avoid frantic mood" => (false, true, false),
        "avoid overly cold emotional tone" => (false, false, true),
        _ => return vec![original.to_string()],
    };

    render_mood_tone_constraint_fragments(
        allow_oppressive && !conflicts("avoid oppressive mood"),
        allow_frantic && !conflicts("avoid frantic mood"),
        allow_cold && !conflicts("avoid overly cold emotional tone"),
    )
}

fn render_mood_tone_constraint_fragments(
    oppressive: bool,
    frantic: bool,
    cold: bool,
) -> Vec<String> {
    if oppressive && frantic && cold {
        return vec!["avoid overly cold, oppressive, or frantic mood".to_string()];
    }
    if oppressive && frantic {
        return vec!["avoid oppressive or frantic mood".to_string()];
    }

    let mut fragments = Vec::new();
    if oppressive {
        fragments.push("avoid oppressive mood".to_string());
    }
    if frantic {
        fragments.push("avoid frantic mood".to_string());
    }
    if cold {
        fragments.push("avoid overly cold emotional tone".to_string());
    }
    fragments
}

fn quality_review_row_matches_storyboard(row: &QualityReviewSeedRow, storyboard_id: i32) -> bool {
    quality_review_storyboard_target_id(row)
        .map(|value| value == storyboard_id)
        .unwrap_or(true)
}

fn quality_review_storyboard_target_id(row: &QualityReviewSeedRow) -> Option<i32> {
    match row.target_type.as_deref().map(str::trim) {
        Some("storyboard") => row
            .target_id
            .as_deref()
            .and_then(|value| value.trim().parse::<i32>().ok()),
        _ => None,
    }
}

#[cfg_attr(not(test), allow(dead_code))]
fn compact_negative_review_constraints(rows: &[QualityReviewSeedRow]) -> Option<String> {
    merge_negative_prompt_fragment_groups(&[collect_negative_review_fragments(rows, 0)])
}

fn collect_negative_review_fragments(
    rows: &[QualityReviewSeedRow],
    storyboard_id: i32,
) -> Vec<String> {
    let mut candidates = Vec::new();
    let mut order = 0usize;
    for row in rows
        .iter()
        .filter(|row| review_row_targets_storyboard(row, storyboard_id))
    {
        if let Some(category) = row.bad_case_category.as_deref() {
            push_scored_negative_fragment(
                &mut candidates,
                &mut order,
                map_bad_case_category_with_comments(category, row.comments.as_deref()),
                true,
                false,
            );
        }
    }
    for row in rows
        .iter()
        .filter(|row| review_row_targets_storyboard(row, storyboard_id))
    {
        if let Some(comments) = row.comments.as_deref() {
            for fragment in infer_negative_fragments_from_comments(comments) {
                push_scored_negative_fragment(
                    &mut candidates,
                    &mut order,
                    Some(fragment),
                    true,
                    true,
                );
            }
        }
    }
    for row in rows
        .iter()
        .filter(|row| !review_row_targets_storyboard(row, storyboard_id))
    {
        if let Some(category) = row.bad_case_category.as_deref() {
            push_scored_negative_fragment(
                &mut candidates,
                &mut order,
                map_bad_case_category_with_comments(category, row.comments.as_deref()),
                false,
                false,
            );
        }
    }
    for row in rows
        .iter()
        .filter(|row| !review_row_targets_storyboard(row, storyboard_id))
    {
        if let Some(comments) = row.comments.as_deref() {
            for fragment in infer_negative_fragments_from_comments(comments) {
                push_scored_negative_fragment(
                    &mut candidates,
                    &mut order,
                    Some(fragment),
                    false,
                    true,
                );
            }
        }
    }
    candidates.sort_by(|a, b| {
        b.score
            .cmp(&a.score)
            .then(a.order.cmp(&b.order))
            .then(a.fragment.cmp(&b.fragment))
    });

    let mut fragments = Vec::new();
    for candidate in candidates {
        push_negative_fragment_without_budget(&mut fragments, &candidate.fragment);
        if fragments.len() >= 6 {
            break;
        }
    }
    fragments
}

fn review_row_targets_storyboard(row: &QualityReviewSeedRow, storyboard_id: i32) -> bool {
    matches!(
        row.target_type.as_deref().map(str::trim),
        Some("storyboard")
    ) && row
        .target_id
        .as_deref()
        .and_then(|value| value.trim().parse::<i32>().ok())
        .is_some_and(|value| value == storyboard_id)
}

fn push_scored_negative_fragment(
    target: &mut Vec<ScoredNegativeFragment>,
    order: &mut usize,
    candidate: Option<&'static str>,
    storyboard_scoped: bool,
    from_comments: bool,
) {
    let Some(fragment) = candidate else {
        return;
    };
    target.push(ScoredNegativeFragment {
        score: score_review_negative_fragment(fragment, storyboard_scoped, from_comments),
        order: *order,
        fragment: fragment.to_string(),
    });
    *order += 1;
}

fn map_bad_case_category(category: &str) -> Option<&'static str> {
    match category.trim() {
        "visual_error" => Some("avoid warped anatomy, blur, flicker"),
        "storyboard_mismatch" => Some("avoid extra shot changes or wrong framing"),
        "character_break" => Some("avoid face drift or costume inconsistency"),
        "pacing_issue" => Some("avoid rushed or jerky motion"),
        "dialogue_issue" => Some("avoid lip-sync mismatch"),
        _ => None,
    }
}

pub(crate) fn map_bad_case_category_with_comments(
    category: &str,
    comments: Option<&str>,
) -> Option<&'static str> {
    let mapped = map_bad_case_category(category)?;
    let Some(comments) = comments else {
        return Some(mapped);
    };
    let comment_fragments = infer_negative_fragments_from_comments(comments);
    match category.trim() {
        "visual_error" if visual_error_category_is_redundant(&comment_fragments) => return None,
        "storyboard_mismatch" if storyboard_mismatch_category_is_redundant(&comment_fragments) => {
            return None;
        }
        "pacing_issue" if pacing_issue_category_is_redundant(&comment_fragments) => return None,
        _ => {}
    }
    Some(mapped)
}

fn visual_error_category_is_redundant(comment_fragments: &[&'static str]) -> bool {
    let mut has_distortion = false;
    let mut has_blur = false;
    let mut has_flicker = false;
    for fragment in comment_fragments {
        match canonical_negative_fragment(fragment).as_str() {
            "avoid warped hands or limbs" | "avoid warped anatomy" => has_distortion = true,
            "avoid blur" => has_blur = true,
            "avoid flicker" | "avoid flicker or motion jitter" => has_flicker = true,
            _ => {}
        }
    }
    has_distortion && has_blur && has_flicker
}

fn storyboard_mismatch_category_is_redundant(comment_fragments: &[&'static str]) -> bool {
    let mut has_shot_change = false;
    let mut has_wrong_framing = false;
    for fragment in comment_fragments {
        match canonical_negative_fragment(fragment).as_str() {
            "avoid unnecessary shot changes" => has_shot_change = true,
            "avoid extreme camera angle"
            | "avoid overly tight close-up framing"
            | "avoid extreme camera angle or overly tight close-up framing" => {
                has_wrong_framing = true;
            }
            _ => {}
        }
    }
    has_shot_change && has_wrong_framing
}

fn pacing_issue_category_is_redundant(comment_fragments: &[&'static str]) -> bool {
    let mut has_rushed_motion = false;
    let mut has_jerky_motion = false;
    for fragment in comment_fragments {
        match canonical_negative_fragment(fragment).as_str() {
            "avoid rushed motion" => has_rushed_motion = true,
            "avoid flicker" | "avoid flicker or motion jitter" => has_jerky_motion = true,
            _ => {}
        }
    }
    has_rushed_motion && has_jerky_motion
}

pub(crate) fn infer_negative_fragments_from_comments(comments: &str) -> Vec<&'static str> {
    let normalized = comments.trim().to_ascii_lowercase();
    let mut fragments = Vec::new();
    let keyword_groups = [
        (
            &[
                "手", "手指", "肢体", "四肢", "畸形", "变形", "anatom", "limb",
            ][..],
            "avoid warped hands or limbs",
        ),
        (
            &["脸", "面部", "五官", "表情崩", "face", "facial"][..],
            "avoid face distortion or identity drift",
        ),
        (
            &["闪烁", "跳帧", "抖动", "flicker", "jitter", "stutter"][..],
            "avoid flicker or motion jitter",
        ),
        (
            &["模糊", "发糊", "虚焦", "blur", "blurry", "soft focus"][..],
            "avoid blur",
        ),
        (
            &[
                "压迫",
                "紧张",
                "太冷",
                "冷调",
                "冷峻",
                "frantic",
                "oppressive",
                "cold mood",
            ][..],
            "avoid overly cold, oppressive, or frantic mood",
        ),
        (
            &[
                "表情僵",
                "表情木",
                "木讷",
                "木然",
                "面瘫",
                "没情绪",
                "没有情绪",
                "情绪太平",
                "语气太平",
                "台词太平",
                "台词生硬",
                "念稿",
                "读稿",
                "像读文章",
                "生硬",
                "monotone",
                "flat delivery",
                "blank expression",
                "wooden",
                "stiff performance",
            ][..],
            "avoid blank expression or monotone delivery",
        ),
        (
            &["逆光", "背光", "剪影", "backlight", "silhouette"][..],
            "avoid harsh backlight silhouette",
        ),
        (
            &[
                "冷光",
                "色温",
                "曝光死",
                "光太平",
                "flat lighting",
                "cold lighting",
            ][..],
            "avoid flat cold lighting",
        ),
        (
            &[
                "霓虹",
                "反光",
                "玻璃反射",
                "雨地反光",
                "车流反光",
                "neon reflection",
                "reflection",
            ][..],
            "avoid distracting neon reflections",
        ),
        (
            &["镜头", "构图", "机位", "切镜", "shot", "framing", "camera"][..],
            "avoid unnecessary shot changes",
        ),
        (
            &[
                "机位太歪",
                "角度太歪",
                "角度极端",
                "仰拍过头",
                "俯拍过头",
                "特写太近",
                "近景太近",
                "裁切太紧",
                "close-up too tight",
                "camera angle too extreme",
                "extreme angle",
                "tight close-up",
            ][..],
            "avoid extreme camera angle or overly tight close-up framing",
        ),
        (
            &[
                "太赶",
                "过赶",
                "过急",
                "太急",
                "过快",
                "太快",
                "节奏赶",
                "动作赶",
                "rushed",
                "too fast",
                "too quick",
                "rush",
            ][..],
            "avoid rushed motion",
        ),
        (
            &["背景", "场景", "空间", "setting", "background"][..],
            "avoid wrong setting details",
        ),
        (
            &["服装", "发型", "角色不一致", "costume", "hair", "character"][..],
            "avoid costume or character drift",
        ),
    ];

    for (keywords, fragment) in keyword_groups {
        if keywords.iter().any(|keyword| normalized.contains(keyword)) {
            fragments.push(fragment);
        }
    }
    fragments
}

fn score_review_negative_fragment(
    fragment: &str,
    storyboard_scoped: bool,
    from_comments: bool,
) -> i32 {
    let source_score = if storyboard_scoped { 48 } else { 0 };
    let detail_score = if from_comments { 8 } else { 0 };
    let canonical = canonical_negative_fragment(fragment);
    let family_score = match negative_fragment_family(fragment) {
        "flicker_motion_jitter" => 36,
        "shot_change_framing" | "camera_framing" => 34,
        "performance_delivery" => 24,
        "lighting_backlight" | "lighting_reflection" => 20,
        "mood_tone" => 16,
        _ => {
            if canonical.contains("face")
                || canonical.contains("costume")
                || canonical.contains("character")
            {
                40
            } else if canonical.contains("warped")
                || canonical.contains("anatom")
                || canonical.contains("blur")
            {
                38
            } else if canonical.contains("setting") {
                18
            } else {
                14
            }
        }
    };
    let breadth_score = [
        canonical.contains("warped") || canonical.contains("anatom"),
        canonical.contains("blur"),
        canonical.contains("flicker") || canonical.contains("jitter"),
        canonical.contains("face") || canonical.contains("identity"),
        canonical.contains("costume") || canonical.contains("character"),
    ]
    .into_iter()
    .filter(|present| *present)
    .count() as i32
        * 4;
    source_score + detail_score + family_score + breadth_score
        - negative_fragment_information_score(fragment) as i32 / 6
}

fn merge_negative_prompts(manual: Option<&str>, automatic: Option<&str>) -> Option<String> {
    merge_negative_prompt_fragment_groups(&[
        split_negative_prompt_fragments(manual),
        split_negative_prompt_fragments(automatic),
    ])
}

fn merge_negative_prompt_fragment_groups(groups: &[Vec<String>]) -> Option<String> {
    let fragments = compact_negative_prompt_fragment_groups(groups);
    let joined = fragments.join(", ");
    let budgeted = if joined.chars().count() <= VIDEO_NEGATIVE_PROMPT_MAX_CHARS {
        fragments
    } else {
        prioritize_negative_prompt_fragments_for_budget(fragments)
    };
    if budgeted.is_empty() {
        None
    } else {
        Some(budgeted.join(", "))
    }
}

fn compact_negative_prompt_fragment_groups(groups: &[Vec<String>]) -> Vec<String> {
    let mut fragments = Vec::new();
    for group in groups {
        for fragment in group {
            push_negative_fragment_without_budget(&mut fragments, fragment);
        }
    }
    compact_negative_fragment_families(fragments)
}

fn prioritize_negative_prompt_fragments_for_budget(fragments: Vec<String>) -> Vec<String> {
    let mut prioritized = fragments
        .into_iter()
        .enumerate()
        .map(|(idx, fragment)| {
            (
                score_negative_prompt_budget_fragment(&fragment),
                negative_fragment_information_score(&fragment),
                idx,
                fragment,
            )
        })
        .collect::<Vec<_>>();
    prioritized.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(a.1.cmp(&b.1))
            .then(a.2.cmp(&b.2))
            .then(a.3.cmp(&b.3))
    });

    let mut budgeted = Vec::new();
    for (_, _, _, fragment) in prioritized {
        push_negative_fragment_with_budget(
            &mut budgeted,
            &fragment,
            VideoNegativePromptBudgetTier::Expanded,
        );
    }
    budgeted
}

fn merge_prioritized_negative_prompt_fragment_groups(
    groups: &[Vec<String>],
    budget_tier: VideoNegativePromptBudgetTier,
) -> Option<String> {
    let mut candidates = Vec::new();
    for (group_idx, group) in groups.iter().enumerate() {
        for (fragment_idx, fragment) in group.iter().enumerate() {
            candidates.push(PrioritizedNegativePromptFragment {
                score: score_negative_prompt_budget_fragment(fragment),
                char_len: negative_fragment_information_score(fragment),
                group_idx,
                fragment_idx,
                fragment: fragment.clone(),
            });
        }
    }
    candidates.sort_by(|a, b| {
        b.score
            .cmp(&a.score)
            .then(a.char_len.cmp(&b.char_len))
            .then(a.group_idx.cmp(&b.group_idx))
            .then(a.fragment_idx.cmp(&b.fragment_idx))
            .then(a.fragment.cmp(&b.fragment))
    });

    let mut fragments = Vec::new();
    for candidate in candidates {
        push_negative_fragment_without_budget(&mut fragments, &candidate.fragment);
    }
    fragments = compact_negative_fragment_families(fragments);
    fragments.sort_by(|left, right| {
        score_negative_prompt_budget_fragment(right)
            .cmp(&score_negative_prompt_budget_fragment(left))
            .then(
                negative_fragment_information_score(left)
                    .cmp(&negative_fragment_information_score(right)),
            )
            .then(left.cmp(right))
    });

    let mut budgeted = Vec::new();
    for fragment in fragments {
        push_negative_fragment_with_budget(&mut budgeted, &fragment, budget_tier);
    }
    if budgeted.is_empty() {
        None
    } else {
        Some(budgeted.join(", "))
    }
}

#[derive(Debug)]
struct PrioritizedNegativePromptFragment {
    score: i32,
    char_len: usize,
    group_idx: usize,
    fragment_idx: usize,
    fragment: String,
}

fn score_negative_prompt_budget_fragment(fragment: &str) -> i32 {
    let canonical = canonical_negative_fragment(fragment);
    let family_score = match negative_fragment_family(fragment) {
        "flicker_motion_jitter" => 36,
        "shot_change_only" => 30,
        "shot_change_framing" | "camera_framing" => 34,
        "performance_delivery" => 26,
        "lighting_backlight" | "lighting_reflection" => 22,
        "mood_tone" => 16,
        _ => 14,
    };
    let detail_score = if canonical.contains("face")
        || canonical.contains("costume")
        || canonical.contains("character")
    {
        40
    } else if canonical.contains("warped")
        || canonical.contains("anatom")
        || canonical.contains("blur")
    {
        38
    } else if canonical.contains("setting") {
        18
    } else {
        0
    };
    let breadth_score = [
        canonical.contains("warped") || canonical.contains("anatom"),
        canonical.contains("blur"),
        canonical.contains("flicker") || canonical.contains("jitter"),
        canonical.contains("face") || canonical.contains("identity"),
        canonical.contains("costume") || canonical.contains("character"),
    ]
    .into_iter()
    .filter(|present| *present)
    .count() as i32
        * 4;
    family_score + detail_score + breadth_score
        - negative_fragment_information_score(fragment) as i32 / 8
}

#[derive(Debug, Default, Clone, Copy)]
struct CharacterConsistencyFlags {
    face_distortion: bool,
    identity_drift: bool,
    costume_inconsistency: bool,
}

#[derive(Debug, Default, Clone, Copy)]
struct VisualStyleConstraintFlags {
    unnecessary_shot_changes: bool,
    extreme_camera_angle: bool,
    tight_close_up: bool,
    oppressive_mood: bool,
    frantic_mood: bool,
    blank_expression_or_monotone_delivery: bool,
    overly_cold_emotional_tone: bool,
    flat_cold_lighting: bool,
    harsh_backlight_silhouette: bool,
    distracting_neon_reflections: bool,
}

#[derive(Debug, Default, Clone, Copy)]
struct VisualErrorFlags {
    warped_anatomy: bool,
    blur: bool,
    flicker: bool,
}

fn compact_negative_fragment_families(fragments: Vec<String>) -> Vec<String> {
    let mut compacted = Vec::with_capacity(fragments.len());
    let mut character_flags = CharacterConsistencyFlags::default();
    let mut character_idx = None;
    let mut visual_style_flags = VisualStyleConstraintFlags::default();
    let mut visual_style_idx = None;
    let mut visual_error_flags = VisualErrorFlags::default();
    let mut visual_error_idx = None;

    for (idx, fragment) in fragments.into_iter().enumerate() {
        if let Some(flags) = parse_character_consistency_fragment(&fragment) {
            character_idx.get_or_insert(idx);
            character_flags.face_distortion |= flags.face_distortion;
            character_flags.identity_drift |= flags.identity_drift;
            character_flags.costume_inconsistency |= flags.costume_inconsistency;
            continue;
        }
        if let Some(flags) = parse_visual_style_constraint_fragment(&fragment) {
            visual_style_idx.get_or_insert(idx);
            visual_style_flags.unnecessary_shot_changes |= flags.unnecessary_shot_changes;
            visual_style_flags.extreme_camera_angle |= flags.extreme_camera_angle;
            visual_style_flags.tight_close_up |= flags.tight_close_up;
            visual_style_flags.oppressive_mood |= flags.oppressive_mood;
            visual_style_flags.frantic_mood |= flags.frantic_mood;
            visual_style_flags.blank_expression_or_monotone_delivery |=
                flags.blank_expression_or_monotone_delivery;
            visual_style_flags.overly_cold_emotional_tone |= flags.overly_cold_emotional_tone;
            visual_style_flags.flat_cold_lighting |= flags.flat_cold_lighting;
            visual_style_flags.harsh_backlight_silhouette |= flags.harsh_backlight_silhouette;
            continue;
        }
        if let Some(flags) = parse_visual_error_fragment(&fragment) {
            visual_error_idx.get_or_insert(idx);
            visual_error_flags.warped_anatomy |= flags.warped_anatomy;
            visual_error_flags.blur |= flags.blur;
            visual_error_flags.flicker |= flags.flicker;
            continue;
        }
        compacted.push((idx, fragment));
    }

    if let Some(idx) = character_idx {
        compacted.push((idx, render_character_consistency_fragment(character_flags)));
    }
    if let Some(idx) = visual_style_idx {
        for fragment in render_visual_style_constraint_fragments(visual_style_flags) {
            compacted.push((idx, fragment));
        }
    }
    if let Some(idx) = visual_error_idx {
        for fragment in render_visual_error_fragments(visual_error_flags) {
            compacted.push((idx, fragment));
        }
    }
    compacted.sort_by(|a, b| a.0.cmp(&b.0));
    compact_rushed_motion_and_jerky_fragment_pair(
        compacted
            .into_iter()
            .map(|(_, fragment)| fragment)
            .collect(),
    )
}

fn parse_character_consistency_fragment(fragment: &str) -> Option<CharacterConsistencyFlags> {
    let canonical = canonical_negative_fragment(fragment);
    match canonical.as_str() {
        "avoid face distortion" => Some(CharacterConsistencyFlags {
            face_distortion: true,
            ..Default::default()
        }),
        "avoid identity drift" => Some(CharacterConsistencyFlags {
            identity_drift: true,
            ..Default::default()
        }),
        "avoid costume drift" => Some(CharacterConsistencyFlags {
            costume_inconsistency: true,
            ..Default::default()
        }),
        "avoid face distortion or identity drift" => Some(CharacterConsistencyFlags {
            face_distortion: true,
            identity_drift: true,
            costume_inconsistency: false,
        }),
        "avoid costume or character drift" => Some(CharacterConsistencyFlags {
            face_distortion: false,
            identity_drift: true,
            costume_inconsistency: true,
        }),
        "avoid face drift or costume inconsistency" => Some(CharacterConsistencyFlags {
            face_distortion: false,
            identity_drift: true,
            costume_inconsistency: true,
        }),
        _ => None,
    }
}

fn render_character_consistency_fragment(flags: CharacterConsistencyFlags) -> String {
    if flags.face_distortion && flags.costume_inconsistency {
        "avoid face distortion, identity drift, costume drift".to_string()
    } else if flags.face_distortion && flags.identity_drift {
        "avoid face distortion or identity drift".to_string()
    } else if flags.identity_drift && flags.costume_inconsistency {
        "avoid costume or character drift".to_string()
    } else if flags.face_distortion {
        "avoid face distortion".to_string()
    } else if flags.identity_drift {
        "avoid identity drift".to_string()
    } else if flags.costume_inconsistency {
        "avoid costume drift".to_string()
    } else {
        "avoid face distortion or identity drift".to_string()
    }
}

fn parse_visual_style_constraint_fragment(fragment: &str) -> Option<VisualStyleConstraintFlags> {
    let canonical = canonical_negative_fragment(fragment);
    match canonical.as_str() {
        "avoid unnecessary shot changes" => Some(VisualStyleConstraintFlags {
            unnecessary_shot_changes: true,
            ..Default::default()
        }),
        "avoid extra shot changes or wrong framing" => Some(VisualStyleConstraintFlags {
            unnecessary_shot_changes: true,
            extreme_camera_angle: true,
            tight_close_up: true,
            ..Default::default()
        }),
        "avoid extreme camera angle" => Some(VisualStyleConstraintFlags {
            extreme_camera_angle: true,
            ..Default::default()
        }),
        "avoid overly tight close-up framing" => Some(VisualStyleConstraintFlags {
            tight_close_up: true,
            ..Default::default()
        }),
        "avoid extreme camera angle or overly tight close-up framing" => {
            Some(VisualStyleConstraintFlags {
                extreme_camera_angle: true,
                tight_close_up: true,
                ..Default::default()
            })
        }
        "avoid oppressive or frantic mood" => Some(VisualStyleConstraintFlags {
            oppressive_mood: true,
            frantic_mood: true,
            ..Default::default()
        }),
        "avoid blank expression" => Some(VisualStyleConstraintFlags {
            blank_expression_or_monotone_delivery: true,
            ..Default::default()
        }),
        "avoid monotone delivery" => Some(VisualStyleConstraintFlags {
            blank_expression_or_monotone_delivery: true,
            ..Default::default()
        }),
        "avoid blank expression or monotone delivery" => Some(VisualStyleConstraintFlags {
            blank_expression_or_monotone_delivery: true,
            ..Default::default()
        }),
        "avoid oppressive mood" => Some(VisualStyleConstraintFlags {
            oppressive_mood: true,
            ..Default::default()
        }),
        "avoid frantic mood" => Some(VisualStyleConstraintFlags {
            frantic_mood: true,
            ..Default::default()
        }),
        "avoid overly cold emotional tone" => Some(VisualStyleConstraintFlags {
            overly_cold_emotional_tone: true,
            ..Default::default()
        }),
        "avoid overly cold, oppressive, or frantic mood" => Some(VisualStyleConstraintFlags {
            oppressive_mood: true,
            frantic_mood: true,
            overly_cold_emotional_tone: true,
            ..Default::default()
        }),
        "avoid flat cold lighting" => Some(VisualStyleConstraintFlags {
            flat_cold_lighting: true,
            ..Default::default()
        }),
        "avoid harsh backlight silhouette" => Some(VisualStyleConstraintFlags {
            harsh_backlight_silhouette: true,
            ..Default::default()
        }),
        "avoid distracting neon reflections" => Some(VisualStyleConstraintFlags {
            distracting_neon_reflections: true,
            ..Default::default()
        }),
        "avoid flat cold lighting or harsh backlight silhouette" => {
            Some(VisualStyleConstraintFlags {
                flat_cold_lighting: true,
                harsh_backlight_silhouette: true,
                ..Default::default()
            })
        }
        _ => None,
    }
}

fn render_visual_style_constraint_fragments(flags: VisualStyleConstraintFlags) -> Vec<String> {
    let mut fragments = Vec::new();
    if flags.unnecessary_shot_changes && (flags.extreme_camera_angle || flags.tight_close_up) {
        fragments.push("avoid extra shot changes or wrong framing".to_string());
    } else if flags.unnecessary_shot_changes {
        fragments.push("avoid unnecessary shot changes".to_string());
    } else if flags.extreme_camera_angle && flags.tight_close_up {
        fragments.push("avoid extreme camera angle or overly tight close-up framing".to_string());
    } else if flags.extreme_camera_angle {
        fragments.push("avoid extreme camera angle".to_string());
    } else if flags.tight_close_up {
        fragments.push("avoid overly tight close-up framing".to_string());
    }

    if flags.oppressive_mood && flags.frantic_mood && flags.overly_cold_emotional_tone {
        fragments.push("avoid overly cold, oppressive, or frantic mood".to_string());
    } else if flags.oppressive_mood && flags.frantic_mood {
        fragments.push("avoid oppressive or frantic mood".to_string());
    } else if flags.oppressive_mood {
        fragments.push("avoid oppressive mood".to_string());
    } else if flags.frantic_mood {
        fragments.push("avoid frantic mood".to_string());
    } else if flags.overly_cold_emotional_tone {
        fragments.push("avoid overly cold emotional tone".to_string());
    }
    if flags.blank_expression_or_monotone_delivery {
        fragments.push("avoid blank expression or monotone delivery".to_string());
    }

    if flags.flat_cold_lighting && flags.harsh_backlight_silhouette {
        fragments.push("avoid flat cold lighting or harsh backlight silhouette".to_string());
    } else if flags.flat_cold_lighting {
        fragments.push("avoid flat cold lighting".to_string());
    } else if flags.harsh_backlight_silhouette {
        fragments.push("avoid harsh backlight silhouette".to_string());
    }
    if flags.distracting_neon_reflections {
        fragments.push("avoid distracting neon reflections".to_string());
    }

    fragments
}

fn parse_visual_error_fragment(fragment: &str) -> Option<VisualErrorFlags> {
    match canonical_negative_fragment(fragment).as_str() {
        "avoid warped anatomy, blur, flicker" => Some(VisualErrorFlags {
            warped_anatomy: true,
            blur: true,
            flicker: true,
        }),
        "avoid warped anatomy or blur" => Some(VisualErrorFlags {
            warped_anatomy: true,
            blur: true,
            ..Default::default()
        }),
        "avoid warped hands or limbs" | "avoid warped anatomy" => Some(VisualErrorFlags {
            warped_anatomy: true,
            ..Default::default()
        }),
        "avoid blur" => Some(VisualErrorFlags {
            blur: true,
            ..Default::default()
        }),
        "avoid flicker" | "avoid flicker or motion jitter" => Some(VisualErrorFlags {
            flicker: true,
            ..Default::default()
        }),
        _ => None,
    }
}

fn render_visual_error_fragments(flags: VisualErrorFlags) -> Vec<String> {
    if flags.warped_anatomy && flags.blur && flags.flicker {
        return vec!["avoid warped anatomy, blur, flicker".to_string()];
    }
    if flags.warped_anatomy && flags.blur {
        return vec!["avoid warped anatomy or blur".to_string()];
    }

    let mut fragments = Vec::new();
    if flags.warped_anatomy {
        fragments.push("avoid warped hands or limbs".to_string());
    }
    if flags.flicker {
        fragments.push("avoid flicker or motion jitter".to_string());
    }
    if flags.blur {
        fragments.push("avoid blur".to_string());
    }
    fragments
}

fn split_negative_prompt_fragments(prompt: Option<&str>) -> Vec<String> {
    let mut raw_fragments = Vec::new();
    if let Some(prompt) = prompt {
        for fragment in prompt.split([',', ';', '，', '；', '\n']) {
            let fragment = fragment.trim();
            if fragment.is_empty() {
                continue;
            }
            raw_fragments.push(fragment.to_string());
        }
    }

    let mut fragments = Vec::new();
    for fragment in stitch_split_negative_fragments(raw_fragments) {
        if negative_fragment_is_covered(&fragment, &fragments) {
            continue;
        }
        fragments.retain(|existing| !negative_fragment_covers(&fragment, existing));
        fragments.push(fragment);
    }
    fragments
}

fn stitch_split_negative_fragments(fragments: Vec<String>) -> Vec<String> {
    let mut stitched = Vec::with_capacity(fragments.len());
    let mut idx = 0usize;
    while idx < fragments.len() {
        if let Some((combined, consumed)) =
            match_known_negative_fragment_sequence(&fragments[idx..])
        {
            stitched.push(combined);
            idx += consumed;
            continue;
        }
        stitched.push(fragments[idx].clone());
        idx += 1;
    }
    stitched
}

fn match_known_negative_fragment_sequence(parts: &[String]) -> Option<(String, usize)> {
    const KNOWN_COMPOSITES: &[(&str, usize)] = &[
        ("avoid overly cold, oppressive, or frantic mood", 3),
        ("avoid warped anatomy, blur, flicker", 3),
        ("avoid face distortion, identity drift, costume drift", 3),
        ("avoid flat cold lighting or harsh backlight silhouette", 1),
    ];

    for &(candidate, consumed) in KNOWN_COMPOSITES {
        if parts.len() < consumed {
            continue;
        }
        let joined = parts[..consumed].join(", ");
        if canonical_negative_fragment(&joined) == canonical_negative_fragment(candidate) {
            return Some((candidate.to_string(), consumed));
        }
    }
    None
}

fn push_negative_fragment_without_budget(target: &mut Vec<String>, candidate: &str) {
    if negative_fragment_is_covered(candidate, target) {
        return;
    }
    target.retain(|existing| !negative_fragment_covers(candidate, existing));
    target.push(candidate.to_string());
}

fn push_negative_fragment_with_budget(
    target: &mut Vec<String>,
    candidate: &str,
    budget_tier: VideoNegativePromptBudgetTier,
) {
    if negative_fragment_is_covered(candidate, target) {
        return;
    }
    target.retain(|existing| !negative_fragment_covers(candidate, existing));
    let mut next = target.clone();
    next.push(candidate.to_string());
    let joined = next.join(", ");
    if next.len() <= negative_prompt_fragment_budget(budget_tier)
        && joined.chars().count() <= negative_prompt_char_budget(budget_tier)
    {
        *target = next;
        return;
    }

    let clipped = clip_negative_prompt(candidate, budget_tier);
    if clipped.is_empty() || negative_fragment_is_covered(&clipped, target) {
        return;
    }
    let mut clipped_next = target.clone();
    clipped_next.push(clipped);
    let clipped_joined = clipped_next.join(", ");
    if clipped_next.len() <= negative_prompt_fragment_budget(budget_tier)
        && clipped_joined.chars().count() <= negative_prompt_char_budget(budget_tier)
    {
        *target = clipped_next;
    }
}

fn negative_fragment_is_covered(candidate: &str, existing_fragments: &[String]) -> bool {
    existing_fragments
        .iter()
        .any(|existing| negative_fragment_covers(existing, candidate))
}

fn character_consistency_flags_cover(
    existing: CharacterConsistencyFlags,
    candidate: CharacterConsistencyFlags,
) -> bool {
    (!candidate.face_distortion || existing.face_distortion)
        && (!candidate.identity_drift || existing.identity_drift)
        && (!candidate.costume_inconsistency || existing.costume_inconsistency)
}

fn visual_error_flags_cover(existing: VisualErrorFlags, candidate: VisualErrorFlags) -> bool {
    (!candidate.warped_anatomy || existing.warped_anatomy)
        && (!candidate.blur || existing.blur)
        && (!candidate.flicker || existing.flicker)
}

fn visual_style_constraint_flags_cover(
    existing: VisualStyleConstraintFlags,
    candidate: VisualStyleConstraintFlags,
) -> bool {
    (!candidate.unnecessary_shot_changes || existing.unnecessary_shot_changes)
        && (!candidate.extreme_camera_angle || existing.extreme_camera_angle)
        && (!candidate.tight_close_up || existing.tight_close_up)
        && (!candidate.oppressive_mood || existing.oppressive_mood)
        && (!candidate.frantic_mood || existing.frantic_mood)
        && (!candidate.blank_expression_or_monotone_delivery
            || existing.blank_expression_or_monotone_delivery)
        && (!candidate.overly_cold_emotional_tone || existing.overly_cold_emotional_tone)
        && (!candidate.flat_cold_lighting || existing.flat_cold_lighting)
        && (!candidate.harsh_backlight_silhouette || existing.harsh_backlight_silhouette)
        && (!candidate.distracting_neon_reflections || existing.distracting_neon_reflections)
}

fn negative_fragment_covers(existing: &str, candidate: &str) -> bool {
    if let (Some(existing_flags), Some(candidate_flags)) = (
        parse_visual_error_fragment(existing),
        parse_visual_error_fragment(candidate),
    ) {
        return visual_error_flags_cover(existing_flags, candidate_flags);
    }
    if let (Some(existing_flags), Some(candidate_flags)) = (
        parse_character_consistency_fragment(existing),
        parse_character_consistency_fragment(candidate),
    ) {
        return character_consistency_flags_cover(existing_flags, candidate_flags);
    }
    if let (Some(existing_flags), Some(candidate_flags)) = (
        parse_visual_style_constraint_fragment(existing),
        parse_visual_style_constraint_fragment(candidate),
    ) {
        return visual_style_constraint_flags_cover(existing_flags, candidate_flags);
    }
    if negative_fragment_same_family(existing, candidate) {
        return negative_fragment_information_score(existing)
            >= negative_fragment_information_score(candidate);
    }
    negative_fragment_contains(existing, candidate)
}

fn compact_rushed_motion_and_jerky_fragment_pair(fragments: Vec<String>) -> Vec<String> {
    let mut compacted = Vec::with_capacity(fragments.len());
    let mut saw_rushed_motion = false;
    let mut saw_motion_jitter = false;

    for fragment in fragments {
        match canonical_negative_fragment(&fragment).as_str() {
            "avoid rushed motion" => saw_rushed_motion = true,
            "avoid flicker or motion jitter" => saw_motion_jitter = true,
            _ => compacted.push(fragment),
        }
    }

    if saw_rushed_motion && saw_motion_jitter {
        compacted.push("avoid rushed or jerky motion".to_string());
    } else {
        if saw_rushed_motion {
            compacted.push("avoid rushed motion".to_string());
        }
        if saw_motion_jitter {
            compacted.push("avoid flicker or motion jitter".to_string());
        }
    }

    compacted
}

fn negative_fragment_contains(existing: &str, candidate: &str) -> bool {
    let existing = canonical_negative_fragment(existing);
    let candidate = canonical_negative_fragment(candidate);
    if existing.is_empty() || candidate.is_empty() {
        return false;
    }
    if existing == candidate {
        return true;
    }
    let min_overlap_len = 12;
    existing.len() >= candidate.len()
        && candidate.len() >= min_overlap_len
        && existing.contains(&candidate)
}

fn negative_fragment_same_family(existing: &str, candidate: &str) -> bool {
    let existing = negative_fragment_family(existing);
    let candidate = negative_fragment_family(candidate);
    !existing.is_empty() && existing == candidate
}

fn negative_fragment_family(value: &str) -> &'static str {
    let canonical = canonical_negative_fragment(value);
    match canonical.as_str() {
        "avoid flicker" | "avoid flicker or motion jitter" => "flicker_motion_jitter",
        "avoid unnecessary shot changes" => "shot_change_only",
        "avoid extra shot changes or wrong framing" => "shot_change_framing",
        "avoid rushed motion" | "avoid rushed or jerky motion" => "rushed_motion",
        "avoid blank expression"
        | "avoid monotone delivery"
        | "avoid blank expression or monotone delivery" => "performance_delivery",
        "avoid extreme camera angle"
        | "avoid overly tight close-up framing"
        | "avoid extreme camera angle or overly tight close-up framing" => "camera_framing",
        "avoid oppressive mood"
        | "avoid frantic mood"
        | "avoid oppressive or frantic mood"
        | "avoid overly cold emotional tone"
        | "avoid overly cold, oppressive, or frantic mood" => "mood_tone",
        "avoid flat cold lighting"
        | "avoid harsh backlight silhouette"
        | "avoid flat cold lighting or harsh backlight silhouette" => "lighting_backlight",
        "avoid distracting neon reflections" => "lighting_reflection",
        "avoid lip-sync mismatch" => "lip_sync_mismatch",
        "avoid face distortion"
        | "avoid identity drift"
        | "avoid costume drift"
        | "avoid face distortion or identity drift"
        | "avoid costume or character drift"
        | "avoid face drift or costume inconsistency"
        | "avoid face distortion, identity drift, costume drift" => "character_consistency",
        _ => "",
    }
}

fn negative_fragment_information_score(value: &str) -> usize {
    canonical_negative_fragment(value).chars().count()
}

fn canonical_negative_fragment(value: &str) -> String {
    value
        .trim()
        .trim_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ',' | ';' | '，' | '；' | '.' | '。' | ':' | '：')
        })
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_ascii_lowercase()
}

fn negative_prompt_char_budget(budget_tier: VideoNegativePromptBudgetTier) -> usize {
    match budget_tier {
        VideoNegativePromptBudgetTier::Lean => VIDEO_NEGATIVE_PROMPT_LEAN_MAX_CHARS,
        VideoNegativePromptBudgetTier::Expanded => VIDEO_NEGATIVE_PROMPT_MAX_CHARS,
    }
}

fn negative_prompt_fragment_budget(budget_tier: VideoNegativePromptBudgetTier) -> usize {
    match budget_tier {
        VideoNegativePromptBudgetTier::Lean => VIDEO_NEGATIVE_PROMPT_LEAN_FRAGMENT_LIMIT,
        VideoNegativePromptBudgetTier::Expanded => usize::MAX,
    }
}

fn clip_negative_prompt(prompt: &str, budget_tier: VideoNegativePromptBudgetTier) -> String {
    let normalized = prompt.split_whitespace().collect::<Vec<_>>().join(" ");
    let mut chars = normalized.chars();
    let clipped = chars
        .by_ref()
        .take(negative_prompt_char_budget(budget_tier))
        .collect::<String>();
    if chars.next().is_some() {
        format!("{}...", clipped.trim_end())
    } else {
        clipped
    }
}

fn infer_video_provider(model: &str) -> &'static str {
    let normalized = model.trim().to_ascii_lowercase();
    if normalized.contains("kling") || normalized.contains("可灵") {
        "kling"
    } else if normalized.contains("pika") {
        "pika"
    } else {
        "runway"
    }
}

#[cfg(test)]
mod tests {
    use super::{
        build_storyboard_negative_prompts, clip_negative_prompt, collect_negative_review_fragments,
        compact_negative_constraint_against_storyboard_style,
        compact_negative_fragment_against_storyboard_risk, compact_negative_review_constraints,
        compact_review_fragments_against_rejected_memory, compact_video_ratio,
        filter_selected_rows_for_subject, infer_negative_fragments_from_comments,
        infer_video_provider, load_auto_negative_prompts, map_bad_case_category_with_comments,
        merge_negative_prompts, negative_fragment_matches_storyboard_risk,
        negative_review_fetch_limit, normalize_upload_sources, pacing_issue_category_is_redundant,
        prune_storyboard_negative_fragments, quality_review_row_matches_storyboard,
        rejected_negative_memory_fetch_limit, resolve_negative_filter_style_note,
        review_fragment_conflicts_with_selected_style, review_fragment_is_irrelevant_to_storyboard,
        selected_memory_fetch_limit, storyboard_dialogue_is_empty,
        storyboard_mismatch_category_is_redundant, visual_error_category_is_redundant,
        QualityReviewSeedRow, VideoNegativePromptBudgetTier, VIDEO_NEGATIVE_PROMPT_MAX_CHARS,
    };
    use crate::production::types::GenerateVideoUploadItem;
    use crate::production::workbench::video_prompt_memory::{
        select_rejected_video_negative_memory_notes, storyboard_prompt_seed, AgentMemoryRow,
        StoryboardPromptSeedRow,
    };
    use sqlx::PgPool;
    use std::collections::HashMap;
    use uuid::Uuid;

    fn storyboard_seed_rows(
        rows: &[(i32, Option<&str>, Option<&str>, Option<&str>)],
    ) -> HashMap<i32, StoryboardPromptSeedRow> {
        rows.iter()
            .map(|(storyboard_id, prompt, video_desc, duration)| {
                (
                    *storyboard_id,
                    StoryboardPromptSeedRow {
                        prompt: prompt.map(str::to_string),
                        video_desc: video_desc.map(str::to_string),
                        duration: duration.map(str::to_string),
                    },
                )
            })
            .collect()
    }

    #[test]
    fn normalize_upload_sources_rejects_duplicate_storyboards() {
        let err = normalize_upload_sources(&[
            GenerateVideoUploadItem {
                id: 3,
                sources: "https://example.com/a.png".into(),
            },
            GenerateVideoUploadItem {
                id: 3,
                sources: "https://example.com/b.png".into(),
            },
        ])
        .unwrap_err();
        assert!(matches!(
            err,
            crate::error::ApiError::BadRequest(message)
                if message == "uploadData must not contain duplicate storyboard ids"
        ));
    }

    #[test]
    fn compact_negative_review_constraints_prefers_short_visual_failures() {
        let prompt = compact_negative_review_constraints(&[
            QualityReviewSeedRow {
                target_type: None,
                target_id: None,
                bad_case_category: Some("visual_error".into()),
                comments: Some("手指变形且有闪烁".into()),
            },
            QualityReviewSeedRow {
                target_type: None,
                target_id: None,
                bad_case_category: Some("character_break".into()),
                comments: Some("角色脸不稳定，服装漂移".into()),
            },
        ])
        .expect("negative prompt");

        assert!(
            prompt.contains("avoid warped hands or limbs")
                || prompt.contains("avoid warped anatomy, blur, flicker")
        );
        assert!(
            prompt.contains("avoid flicker or motion jitter")
                || prompt.contains("avoid warped anatomy, blur, flicker")
        );
        assert!(prompt.contains("avoid face distortion, identity drift, costume drift"));
        assert!(!prompt.contains("avoid costume or character drift"));
    }

    #[test]
    fn infer_negative_fragments_from_comments_matches_cn_and_en_keywords() {
        let fragments = infer_negative_fragments_from_comments(
            "面部崩坏并且 flicker，镜头切换也多而且画面发糊",
        );
        assert!(fragments.contains(&"avoid face distortion or identity drift"));
        assert!(fragments.contains(&"avoid flicker or motion jitter"));
        assert!(fragments.contains(&"avoid blur"));
        assert!(fragments.contains(&"avoid unnecessary shot changes"));
    }

    #[test]
    fn visual_error_category_is_redundant_when_comments_already_cover_multiple_visual_axes() {
        assert!(visual_error_category_is_redundant(
            &infer_negative_fragments_from_comments("手指变形、画面模糊还有闪烁")
        ));
        assert!(!visual_error_category_is_redundant(
            &infer_negative_fragments_from_comments("手指变形还有闪烁")
        ));
    }

    #[test]
    fn storyboard_mismatch_category_is_redundant_when_comments_cover_shot_change_and_framing() {
        assert!(storyboard_mismatch_category_is_redundant(
            &infer_negative_fragments_from_comments("切镜太多而且近景裁切太紧")
        ));
        assert!(!storyboard_mismatch_category_is_redundant(
            &infer_negative_fragments_from_comments("切镜太多")
        ));
    }

    #[test]
    fn prune_storyboard_negative_fragments_drops_unmatched_risk_for_grounded_silent_shot() {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（男主坐在木桌前、室内书房、男主、4秒、中景、静止、低头翻开信纸、平静、室内暖光、无台词、纸张摩擦声、A03）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

        assert_eq!(
            prune_storyboard_negative_fragments(
                vec![
                    "avoid lip-sync mismatch".into(),
                    "avoid harsh backlight silhouette".into(),
                    "avoid face distortion or identity drift".into(),
                ],
                Some(&storyboard_row),
            ),
            vec!["avoid face distortion or identity drift".to_string()]
        );
    }

    #[test]
    fn negative_fragment_matches_storyboard_risk_keeps_dialogue_and_lighting_for_risky_shot() {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（女主逼近门厅、旧宅门厅、女主、5秒、近景、推进、停步回头、克制、冷调逆光、你别再骗我、风声回响、A12）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };

        assert!(negative_fragment_matches_storyboard_risk(
            "avoid lip-sync mismatch",
            Some(&storyboard_row),
        ));
        assert!(negative_fragment_matches_storyboard_risk(
            "avoid harsh backlight silhouette",
            Some(&storyboard_row),
        ));
        assert!(negative_fragment_matches_storyboard_risk(
            "avoid extreme camera angle or overly tight close-up framing",
            Some(&storyboard_row),
        ));
    }

    #[test]
    fn compact_negative_fragment_against_storyboard_risk_keeps_shot_change_only_for_grounded_shot()
    {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、静止、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

        assert_eq!(
            compact_negative_fragment_against_storyboard_risk(
                "avoid extra shot changes or wrong framing",
                Some(&storyboard_row),
            )
            .as_deref(),
            Some("avoid unnecessary shot changes")
        );
    }

    #[test]
    fn compact_negative_fragment_against_storyboard_risk_drops_motion_half_for_static_visual_error()
    {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、静止、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

        assert_eq!(
            compact_negative_fragment_against_storyboard_risk(
                "avoid warped anatomy, blur, flicker",
                Some(&storyboard_row),
            )
            .as_deref(),
            Some("avoid warped anatomy or blur")
        );
    }

    #[test]
    fn compact_negative_fragment_against_storyboard_risk_keeps_only_matching_lighting_half() {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（林晚停在门厅、旧宅门厅、林晚、5秒、中景、静止、停步抬头、克制、阴天冷光、无台词、风声回响、A12）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };

        assert_eq!(
            compact_negative_fragment_against_storyboard_risk(
                "avoid flat cold lighting or harsh backlight silhouette",
                Some(&storyboard_row),
            )
            .as_deref(),
            Some("avoid flat cold lighting")
        );
    }

    #[test]
    fn compact_negative_fragment_against_storyboard_risk_swaps_generic_lighting_bundle_for_reflection_axis(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（主角穿过雨巷、霓虹雨巷、主角、5秒、中景、稳定跟拍、踩水快步穿行、克制、霓虹反光、无台词、雨声脚步声、A12）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };

        assert_eq!(
            compact_negative_fragment_against_storyboard_risk(
                "avoid flat cold lighting or harsh backlight silhouette",
                Some(&storyboard_row),
            )
            .as_deref(),
            Some("avoid distracting neon reflections")
        );
    }

    #[test]
    fn pacing_issue_category_is_redundant_when_comments_cover_rushed_and_jerky_motion() {
        assert!(pacing_issue_category_is_redundant(
            &infer_negative_fragments_from_comments("动作太赶，还有明显抖动")
        ));
        assert!(!pacing_issue_category_is_redundant(
            &infer_negative_fragments_from_comments("动作太赶")
        ));
    }

    #[test]
    fn map_bad_case_category_with_comments_skips_visual_error_when_comments_are_specific_enough() {
        assert_eq!(
            map_bad_case_category_with_comments("visual_error", Some("手指变形、画面模糊还有闪烁")),
            None
        );
        assert_eq!(
            map_bad_case_category_with_comments("visual_error", Some("手指变形还有闪烁")),
            Some("avoid warped anatomy, blur, flicker")
        );
        assert_eq!(
            map_bad_case_category_with_comments(
                "storyboard_mismatch",
                Some("切镜太多而且近景裁切太紧")
            ),
            None
        );
        assert_eq!(
            map_bad_case_category_with_comments("pacing_issue", Some("动作太赶，还有明显抖动")),
            None
        );
        assert_eq!(
            map_bad_case_category_with_comments("pacing_issue", Some("动作太赶")),
            Some("avoid rushed or jerky motion")
        );
    }

    #[test]
    fn collect_negative_review_fragments_prioritizes_storyboard_specific_high_value_constraints() {
        let fragments = collect_negative_review_fragments(
            &[
                QualityReviewSeedRow {
                    target_type: Some("output".into()),
                    target_id: None,
                    bad_case_category: Some("storyboard_mismatch".into()),
                    comments: None,
                },
                QualityReviewSeedRow {
                    target_type: Some("output".into()),
                    target_id: None,
                    bad_case_category: Some("visual_error".into()),
                    comments: Some("背景不对而且镜头切换太多".into()),
                },
                QualityReviewSeedRow {
                    target_type: Some("storyboard".into()),
                    target_id: Some("12".into()),
                    bad_case_category: Some("character_break".into()),
                    comments: Some("角色脸不稳定，服装漂移".into()),
                },
            ],
            12,
        );

        assert_eq!(
            fragments.first().map(String::as_str),
            Some("avoid costume or character drift")
        );
        assert!(fragments.contains(&"avoid warped anatomy, blur, flicker".to_string()));
        assert!(fragments.contains(&"avoid extra shot changes or wrong framing".to_string()));
    }

    #[test]
    fn collect_negative_review_fragments_skips_generic_visual_error_when_comments_are_specific() {
        let fragments = collect_negative_review_fragments(
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: Some("visual_error".into()),
                comments: Some("手指变形、画面模糊还有闪烁".into()),
            }],
            12,
        );

        assert!(fragments.contains(&"avoid warped hands or limbs".to_string()));
        assert!(fragments.contains(&"avoid blur".to_string()));
        assert!(fragments.contains(&"avoid flicker or motion jitter".to_string()));
        assert!(!fragments.contains(&"avoid warped anatomy, blur, flicker".to_string()));
    }

    #[test]
    fn collect_negative_review_fragments_pulls_reflection_guard_from_comments() {
        let fragments = collect_negative_review_fragments(
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("霓虹反光太脏，玻璃反射抢戏".into()),
            }],
            12,
        );

        assert!(fragments.contains(&"avoid distracting neon reflections".to_string()));
    }

    #[test]
    fn collect_negative_review_fragments_skips_generic_storyboard_and_pacing_tags_when_comments_are_specific(
    ) {
        let fragments = collect_negative_review_fragments(
            &[
                QualityReviewSeedRow {
                    target_type: Some("storyboard".into()),
                    target_id: Some("12".into()),
                    bad_case_category: Some("storyboard_mismatch".into()),
                    comments: Some("切镜太多而且近景裁切太紧".into()),
                },
                QualityReviewSeedRow {
                    target_type: Some("storyboard".into()),
                    target_id: Some("12".into()),
                    bad_case_category: Some("pacing_issue".into()),
                    comments: Some("动作太赶，还有明显抖动".into()),
                },
            ],
            12,
        );

        assert!(fragments.contains(&"avoid unnecessary shot changes".to_string()));
        assert!(fragments
            .contains(&"avoid extreme camera angle or overly tight close-up framing".to_string()));
        assert!(fragments.contains(&"avoid rushed motion".to_string()));
        assert!(fragments.contains(&"avoid flicker or motion jitter".to_string()));
        assert!(!fragments.contains(&"avoid extra shot changes or wrong framing".to_string()));
        assert!(!fragments.contains(&"avoid rushed or jerky motion".to_string()));
    }

    #[test]
    fn compact_negative_constraint_against_storyboard_style_keeps_non_conflicting_half() {
        let close_up_storyboard = StoryboardPromptSeedRow {
            prompt: Some("门口逼视".into()),
            video_desc: Some(
                "（主角逼视来人、旧宅门口、主角、5秒、近景、静止、逼近对手、克制、侧逆光、、、A15）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };
        assert_eq!(
            compact_negative_constraint_against_storyboard_style(
                "avoid extreme camera angle or overly tight close-up framing",
                None,
                Some(&close_up_storyboard),
            ),
            Some("avoid extreme camera angle".to_string())
        );

        let cold_light_storyboard = StoryboardPromptSeedRow {
            prompt: Some("冷光对峙".into()),
            video_desc: Some(
                "（主角对峙、旧宅门厅、主角、5秒、中景、静止、盯住来人、冷峻压迫、室内冷光、、、A16）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };
        assert_eq!(
            compact_negative_constraint_against_storyboard_style(
                "avoid flat cold lighting or harsh backlight silhouette",
                None,
                Some(&cold_light_storyboard),
            ),
            Some("avoid harsh backlight silhouette".to_string())
        );
    }

    #[test]
    fn compact_negative_constraint_against_storyboard_style_keeps_frantic_guard_for_cold_scene() {
        let cold_oppressive_storyboard = StoryboardPromptSeedRow {
            prompt: Some("冷光对峙".into()),
            video_desc: Some(
                "（主角对峙、旧宅门厅、主角、5秒、中景、静止、盯住来人、冷峻压迫、室内冷光、、、A16）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };
        assert_eq!(
            compact_negative_constraint_against_storyboard_style(
                "avoid overly cold, oppressive, or frantic mood",
                None,
                Some(&cold_oppressive_storyboard),
            ),
            Some("avoid frantic mood".to_string())
        );
    }

    #[test]
    fn merge_negative_prompts_deduplicates_and_clips() {
        let merged = merge_negative_prompts(
            Some("avoid blur, avoid flicker"),
            Some("avoid flicker, avoid wrong setting details"),
        )
        .expect("merged prompt");
        assert_eq!(
            merged,
            "avoid blur, avoid flicker, avoid wrong setting details"
        );
        assert!(
            clip_negative_prompt(&"a".repeat(160), VideoNegativePromptBudgetTier::Expanded)
                .ends_with("...")
        );
    }

    #[test]
    fn merge_negative_prompts_keeps_more_informative_fragment() {
        let merged = merge_negative_prompts(
            Some("avoid flicker"),
            Some("avoid flicker or motion jitter, avoid blur"),
        )
        .expect("merged prompt");

        assert_eq!(merged, "avoid blur, avoid flicker or motion jitter");
    }

    #[test]
    fn merge_negative_prompts_prefers_more_informative_shot_change_fragment() {
        let merged = merge_negative_prompts(
            Some("avoid unnecessary shot changes"),
            Some("avoid extra shot changes or wrong framing, avoid blur"),
        )
        .expect("merged prompt");

        assert_eq!(
            merged,
            "avoid extra shot changes or wrong framing, avoid blur"
        );
    }

    #[test]
    fn merge_negative_prompts_compacts_character_consistency_family() {
        let merged = merge_negative_prompts(
            Some("avoid face drift or costume inconsistency"),
            Some("avoid face distortion or identity drift, avoid costume or character drift"),
        )
        .expect("merged prompt");

        assert_eq!(
            merged,
            "avoid face distortion, identity drift, costume drift"
        );
    }

    #[test]
    fn merge_negative_prompts_compacts_character_consistency_singletons() {
        let merged = merge_negative_prompts(
            Some("avoid identity drift"),
            Some("avoid face distortion, avoid costume drift"),
        )
        .expect("merged prompt");

        assert_eq!(
            merged,
            "avoid face distortion, identity drift, costume drift"
        );
    }

    #[test]
    fn merge_negative_prompts_compacts_performance_delivery_singletons() {
        let merged = merge_negative_prompts(
            Some("avoid blank expression"),
            Some("avoid monotone delivery"),
        )
        .expect("merged prompt");

        assert_eq!(merged, "avoid blank expression or monotone delivery");
    }

    #[test]
    fn merge_negative_prompts_compacts_visual_style_families() {
        let merged = merge_negative_prompts(
            Some(
                "avoid extreme camera angle, avoid oppressive or frantic mood, avoid flat cold lighting",
            ),
            Some(
                "avoid overly tight close-up framing, avoid overly cold emotional tone, avoid harsh backlight silhouette",
            ),
        )
        .expect("merged prompt");

        assert_eq!(
            merged,
            "avoid extreme camera angle or overly tight close-up framing, avoid flat cold lighting or harsh backlight silhouette"
        );
    }

    #[test]
    fn merge_negative_prompts_compacts_shot_change_and_framing_into_single_fragment() {
        let merged = merge_negative_prompts(
            Some("avoid unnecessary shot changes"),
            Some("avoid extreme camera angle or overly tight close-up framing"),
        )
        .expect("merged prompt");

        assert_eq!(merged, "avoid extra shot changes or wrong framing");
    }

    #[test]
    fn merge_negative_prompts_compacts_rushed_and_jerky_motion_into_single_fragment() {
        let merged = merge_negative_prompts(
            Some("avoid rushed motion"),
            Some("avoid flicker or motion jitter"),
        )
        .expect("merged prompt");

        assert_eq!(merged, "avoid rushed or jerky motion");
    }

    #[test]
    fn merge_negative_prompts_compacts_visual_error_family_before_budgeting() {
        let merged = merge_negative_prompts(
            Some("avoid blur, avoid flicker"),
            Some("avoid warped hands or limbs"),
        )
        .expect("merged prompt");

        assert_eq!(merged, "avoid warped anatomy, blur, flicker");
    }

    #[test]
    fn merge_negative_prompts_visual_error_bundle_covers_individual_fragments() {
        let merged = merge_negative_prompts(
            Some("avoid warped anatomy, blur, flicker"),
            Some("avoid blur, avoid flicker or motion jitter"),
        )
        .expect("merged prompt");

        assert_eq!(merged, "avoid warped anatomy, blur, flicker");
    }

    #[tokio::test]
    async fn load_auto_negative_prompts_returns_empty_without_storyboards() {
        let pool = PgPool::connect_lazy("postgres://postgres:postgres@localhost/postgres")
            .expect("lazy pool");
        let prompts = load_auto_negative_prompts(&pool, Uuid::nil(), 1, 2, &[])
            .await
            .expect("prompts");
        assert!(prompts.is_empty());
    }

    #[test]
    fn negative_review_fetch_limit_scales_with_storyboard_batch_size() {
        assert_eq!(negative_review_fetch_limit(0), 8);
        assert_eq!(negative_review_fetch_limit(1), 12);
        assert_eq!(negative_review_fetch_limit(3), 20);
        assert_eq!(negative_review_fetch_limit(8), 24);
    }

    #[test]
    fn rejected_video_negative_memory_can_merge_with_review_constraints() {
        let rows = vec![
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=9 | rejectionCount=2 | avoid=avoid shaky handheld motion".into(),
            },
        ];
        let merged = merge_negative_prompts(
            Some("avoid flicker"),
            select_rejected_video_negative_memory_notes(&rows, 12, None)
                .first()
                .map(String::as_str),
        )
        .expect("merged");

        assert_eq!(
            merged,
            "avoid flicker, avoid oppressive or frantic mood, avoid flat cold lighting"
        );
    }

    #[test]
    fn negative_filter_style_note_skips_contextual_summary_when_it_only_repeats_storyboard_axes() {
        let rows = vec![
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光，人物持续逼近 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光，人物持续逼近".into(),
            },
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            },
        ];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("门厅对峙".into()),
            video_desc: Some("（主角对峙、旧宅门厅、主角、5秒、中景、稳定跟拍、逼近对手、冷峻压迫、冷调逆光、、、A12）".into()),
            duration: Some("5".into()),
        };

        assert_eq!(
            resolve_negative_filter_style_note(&rows, 12, None, Some(&storyboard_row), None, &[]),
            None
        );
    }

    #[test]
    fn negative_filter_style_note_skips_summary_that_only_repeats_storyboard_fields() {
        let rows = vec![AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content: "sampleCount=5 | style=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光 | note=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光".into(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、稳定跟拍、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5".into()),
        };

        assert_eq!(
            resolve_negative_filter_style_note(&rows, 12, None, Some(&storyboard_row), None, &[]),
            None
        );
    }

    #[test]
    fn negative_filter_style_note_prefers_matching_role_memory_before_generic_summary() {
        let rows = vec![
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=6 | style=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=女主 | subjectAliases=女主/苏晚 | sampleCount=3 | style=表演欲言又止，语气轻声克制".into(),
            },
        ];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、稳定跟拍、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5".into()),
        };

        assert_eq!(
            resolve_negative_filter_style_note(
                &rows,
                12,
                None,
                Some(&storyboard_row),
                None,
                &["女主".into(), "苏晚".into()],
            ),
            Some("表演欲言又止，语气轻声克制".to_string())
        );
    }

    #[test]
    fn negative_filter_style_note_lets_role_memory_override_low_signal_exact_camera_note() {
        let rows = vec![AgentMemoryRow {
            name: "script_role_video_style_memory".into(),
            content: "subject=女主 | subjectAliases=女主/苏晚 | sampleCount=3 | style=表演欲言又止，语气轻声克制".into(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、稳定跟拍、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5".into()),
        };

        assert_eq!(
            resolve_negative_filter_style_note(
                &rows,
                12,
                None,
                Some(&storyboard_row),
                Some("镜头稳定跟拍".to_string()),
                &["女主".into(), "苏晚".into()],
            ),
            Some("表演欲言又止，语气轻声克制".to_string())
        );
    }

    #[test]
    fn negative_filter_style_note_keeps_exact_note_when_camera_fragment_carries_emotion_signal() {
        let rows = vec![AgentMemoryRow {
            name: "script_role_video_style_memory".into(),
            content: "subject=女主 | subjectAliases=女主/苏晚 | sampleCount=3 | style=表演欲言又止，语气轻声克制".into(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、稳定跟拍、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5".into()),
        };

        assert_eq!(
            resolve_negative_filter_style_note(
                &rows,
                12,
                None,
                Some(&storyboard_row),
                Some("镜头稳定跟拍，情绪克制停顿".to_string()),
                &["女主".into(), "苏晚".into()],
            ),
            Some("镜头稳定跟拍，情绪克制停顿".to_string())
        );
    }

    #[test]
    fn merge_negative_prompts_compacts_lighting_family_before_budgeting() {
        let merged = merge_negative_prompts(
            Some("avoid flicker"),
            Some("avoid flat cold lighting, avoid harsh backlight silhouette"),
        )
        .expect("merged");

        assert_eq!(
            merged,
            "avoid flicker, avoid flat cold lighting or harsh backlight silhouette"
        );
    }

    #[test]
    fn merge_negative_prompts_prioritizes_higher_value_automatic_constraints_when_over_budget() {
        let merged = merge_negative_prompts(
            Some(
                "avoid extra shot changes or wrong framing, avoid overly cold, oppressive, or frantic mood, avoid flat cold lighting or harsh backlight silhouette, avoid wrong setting details",
            ),
            Some(
                "avoid face distortion or identity drift, avoid costume or character drift, avoid warped hands or limbs, avoid blur, avoid flicker",
            ),
        )
        .expect("merged");

        assert!(merged.contains("avoid face distortion, identity drift, costume drift"));
        assert!(merged.contains("avoid warped anatomy, blur, flicker"));
        assert!(!merged.contains("avoid overly cold, oppressive, or frantic mood"));
        assert!(merged.chars().count() <= VIDEO_NEGATIVE_PROMPT_MAX_CHARS);
    }

    #[test]
    fn quality_review_row_matches_storyboard_keeps_storyboard_scope_isolated() {
        let storyboard_row = QualityReviewSeedRow {
            target_type: Some("storyboard".into()),
            target_id: Some("12".into()),
            bad_case_category: Some("storyboard_mismatch".into()),
            comments: None,
        };
        let global_row = QualityReviewSeedRow {
            target_type: Some("video".into()),
            target_id: None,
            bad_case_category: Some("visual_error".into()),
            comments: None,
        };

        assert!(quality_review_row_matches_storyboard(&storyboard_row, 12));
        assert!(!quality_review_row_matches_storyboard(&storyboard_row, 9));
        assert!(quality_review_row_matches_storyboard(&global_row, 9));
    }

    #[test]
    fn build_storyboard_negative_prompts_keeps_each_storyboard_prompt_independent() {
        let prompts = build_storyboard_negative_prompts(
            &[12, 13],
            &[
                QualityReviewSeedRow {
                    target_type: Some("storyboard".into()),
                    target_id: Some("12".into()),
                    bad_case_category: Some("storyboard_mismatch".into()),
                    comments: None,
                },
                QualityReviewSeedRow {
                    target_type: Some("output".into()),
                    target_id: None,
                    bad_case_category: Some("visual_error".into()),
                    comments: Some("有明显闪烁".into()),
                },
            ],
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=13 | rejectionCount=2 | avoid=avoid flat cold lighting"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=2 | avoid=avoid oppressive or frantic mood"
                            .into(),
                },
            ],
            &[],
            &HashMap::new(),
        );

        let prompt_12 = prompts
            .get(&12)
            .and_then(|value| value.as_deref())
            .expect("storyboard 12 prompt");
        let prompt_13 = prompts
            .get(&13)
            .and_then(|value| value.as_deref())
            .expect("storyboard 13 prompt");

        assert!(prompt_12.contains("avoid extra shot changes or wrong framing"));
        assert!(prompt_12.contains("avoid warped anatomy, blur, flicker"));
        assert!(prompt_12.contains("avoid op"));
        assert!(!prompt_12.contains("avoid flat cold lighting"));

        assert!(prompt_13.contains("avoid warped anatomy, blur, flicker"));
        assert!(prompt_13.contains("avoid flat cold lighting"));
        assert!(!prompt_13.contains("avoid extra shot changes or wrong framing"));
    }

    #[test]
    fn build_storyboard_negative_prompts_prefers_matching_role_rejected_memory_alias() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | avoid=avoid identity drift".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | rejectionCount=3 | avoid=avoid lip-sync mismatch".into(),
                },
            ],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("晚晚强忍泪意看向门外"),
                Some("（晚晚强忍泪意看向门外、雨夜门厅、晚晚/林晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、克制、冷调逆光、无台词、雨声回响、A12）"),
                Some("5s"),
            )]),
        );

        assert_eq!(
            prompts.get(&12).and_then(|value| value.as_deref()),
            Some("avoid identity drift")
        );
        assert_eq!(
            prompts.get(&12).map(|value| value.budget_tier),
            Some("expanded")
        );
    }

    #[test]
    fn build_storyboard_negative_prompts_uses_lean_budget_for_low_risk_single_axis_warning() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("output".into()),
                target_id: None,
                bad_case_category: Some("pacing_issue".into()),
                comments: None,
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("林晚站在窗边"),
                Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）"),
                Some("4s"),
            )]),
        );

        let selection = prompts.get(&12).expect("storyboard 12 prompt");
        assert_eq!(selection.as_deref(), Some("avoid rushed or jerky motion"));
        assert_eq!(selection.fragment_count, 1);
        assert_eq!(selection.budget_tier, "lean");
    }

    #[test]
    fn build_storyboard_negative_prompts_keeps_lean_budget_for_single_subject_low_risk_warning() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("output".into()),
                target_id: None,
                bad_case_category: Some("pacing_issue".into()),
                comments: None,
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("晚晚站在窗边"),
                Some("（晚晚站在窗边、咖啡厅窗边、晚晚/林晚、4秒、中景、静止、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）"),
                Some("4s"),
            )]),
        );

        let selection = prompts.get(&12).expect("storyboard 12 prompt");
        assert_eq!(selection.as_deref(), Some("avoid rushed or jerky motion"));
        assert_eq!(selection.fragment_count, 1);
        assert_eq!(selection.budget_tier, "lean");
    }

    #[test]
    fn build_storyboard_negative_prompts_keeps_shot_change_guard_for_grounded_storyboard_mismatch()
    {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("output".into()),
                target_id: None,
                bad_case_category: Some("storyboard_mismatch".into()),
                comments: None,
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("林晚站在窗边"),
                Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、静止、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）"),
                Some("4s"),
            )]),
        );

        let selection = prompts.get(&12).expect("storyboard 12 prompt");
        assert_eq!(selection.as_deref(), Some("avoid unnecessary shot changes"));
        assert_eq!(selection.fragment_count, 1);
    }

    #[test]
    fn build_storyboard_negative_prompts_trims_storyboard_mismatch_to_framing_only_axis() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("output".into()),
                target_id: None,
                bad_case_category: Some("storyboard_mismatch".into()),
                comments: None,
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("主角抬头看向楼梯上方"),
                Some("（主角抬头看向楼梯上方、旧宅楼梯口、主角、4秒、仰拍中景、静止、抬头盯住楼上、压抑、室内暖光、无台词、木地板回响、A12）"),
                Some("4s"),
            )]),
        );

        let selection = prompts.get(&12).expect("storyboard 12 prompt");
        assert_eq!(selection.as_deref(), Some("avoid extreme camera angle"));
        assert_eq!(selection.fragment_count, 1);
        assert_eq!(selection.budget_tier, "lean");
    }

    #[test]
    fn build_storyboard_negative_prompts_trims_storyboard_mismatch_to_tight_close_up_only_axis() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("output".into()),
                target_id: None,
                bad_case_category: Some("storyboard_mismatch".into()),
                comments: None,
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("主角压低声音盯住来人"),
                Some("（主角压低声音盯住来人、旧宅门厅、主角、4秒、特写、静止、盯住来人、克制、室内暖光、你终于来了、空调低鸣、A12）"),
                Some("4s"),
            )]),
        );

        let selection = prompts.get(&12).expect("storyboard 12 prompt");
        assert_eq!(
            selection.as_deref(),
            Some("avoid overly tight close-up framing")
        );
        assert_eq!(selection.fragment_count, 1);
        assert_eq!(selection.budget_tier, "lean");
    }

    #[test]
    fn build_storyboard_negative_prompts_keeps_expanded_budget_for_single_subject_identity_warning()
    {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("output".into()),
                target_id: None,
                bad_case_category: Some("character_break".into()),
                comments: None,
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("晚晚站在窗边"),
                Some("（晚晚站在窗边、咖啡厅窗边、晚晚/林晚、4秒、中景、静止、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）"),
                Some("4s"),
            )]),
        );

        let selection = prompts.get(&12).expect("storyboard 12 prompt");
        assert_eq!(
            selection.as_deref(),
            Some("avoid face drift or costume inconsistency")
        );
        assert_eq!(selection.fragment_count, 1);
        assert_eq!(selection.budget_tier, "expanded");
    }

    #[test]
    fn build_storyboard_negative_prompts_compacts_broad_mood_guard_for_restrained_scene() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid overly cold, oppressive, or frantic mood"
                        .into(),
            }],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("晚晚低声忍住眼泪"),
                Some("（晚晚低声忍住眼泪、医院走廊、晚晚/林晚、5秒、中景、静止、停顿后低声开口、克制、夜间中性光、别问了、空调低鸣、A12）"),
                Some("5s"),
            )]),
        );

        let selection = prompts.get(&12).expect("storyboard 12 prompt");
        assert_eq!(selection.as_deref(), Some("avoid frantic mood"));
        assert_eq!(selection.budget_tier, "lean");
    }

    #[test]
    fn build_storyboard_negative_prompts_keeps_performance_guard_for_restrained_dialogue_scene() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("台词像读文章，表情发木没情绪".into()),
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("晚晚低声开口"),
                Some("（晚晚低声开口、医院走廊、晚晚/林晚、5秒、中景、静止、停顿后低声开口、克制、夜间中性光、别再问了、空调低鸣、A12）"),
                Some("5s"),
            )]),
        );

        let selection = prompts.get(&12).expect("storyboard 12 prompt");
        assert_eq!(
            selection.as_deref(),
            Some("avoid blank expression or monotone delivery")
        );
        assert_eq!(selection.fragment_count, 1);
    }

    #[test]
    fn build_storyboard_negative_prompts_drops_redundant_frantic_guard_when_review_flags_monotone_restrained_scene(
    ) {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("台词像读文章，表情发木没情绪".into()),
            }],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid overly cold, oppressive, or frantic mood"
                        .into(),
            }],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("晚晚低声开口"),
                Some("（晚晚低声开口、医院走廊、晚晚/林晚、5秒、中景、静止、停顿后低声开口、克制、夜间中性光、别再问了、空调低鸣、A12）"),
                Some("5s"),
            )]),
        );

        let selection = prompts.get(&12).expect("storyboard 12 prompt");
        assert_eq!(
            selection.as_deref(),
            Some("avoid blank expression or monotone delivery")
        );
        assert_eq!(selection.fragment_count, 1);
        assert_eq!(selection.budget_tier, "lean");
    }

    #[test]
    fn build_storyboard_negative_prompts_drops_performance_guard_for_non_emotional_silent_scene() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("台词像读文章，表情发木没情绪".into()),
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("主角站在门口"),
                Some("（主角站在门口、旧宅门厅、主角、4秒、中景、静止、站在门口、平静、室内暖光、无台词、风声、A12）"),
                Some("4s"),
            )]),
        );

        assert_eq!(prompts.get(&12).and_then(|value| value.as_deref()), None);
    }

    #[test]
    fn build_storyboard_negative_prompts_falls_back_to_pending_observation_when_no_promoted_negative_exists(
    ) {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=1 | avoid=avoid flicker or motion jitter"
                        .into(),
            }],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("主角冲下楼梯"),
                Some("（主角冲下楼梯、旧宅楼梯、主角、5秒、近景、稳定跟拍、冲下楼梯、紧张、室内冷光、快走、急促脚步声、A12）"),
                Some("5s"),
            )]),
        );

        let selection = prompts.get(&12).expect("storyboard 12 prompt");
        assert_eq!(selection.as_deref(), Some("avoid flicker or motion jitter"));
        assert_eq!(selection.fragment_count, 1);
        assert_eq!(selection.budget_tier, "lean");
        assert_eq!(selection.review_fragment_count, 0);
        assert_eq!(selection.rejected_memory_fragment_count, 1);
        assert!(selection.used_pending_observation_fallback);
        assert_eq!(
            selection.source_label(),
            Some("pending_rejected_observation")
        );
    }

    #[test]
    fn build_storyboard_negative_prompts_narrows_frantic_guard_for_intended_panic_scene() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid overly cold, oppressive, or frantic mood"
                        .into(),
            }],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("主角惊慌冲出门厅"),
                Some("（主角惊慌冲出门厅、旧宅门厅、主角、5秒、近景、手持跟拍、狂奔冲出门厅、惊慌失控、车灯逆光、快跑啊、呼吸急促混着脚步声、A12）"),
                Some("5s"),
            )]),
        );

        assert_eq!(
            prompts.get(&12).and_then(|value| value.as_deref()),
            Some("avoid oppressive mood")
        );
    }

    #[test]
    fn build_storyboard_negative_prompts_keeps_frantic_guard_for_cold_oppressive_mood() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid overly cold, oppressive, or frantic mood"
                        .into(),
            }],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("主角站在门厅冷静对峙"),
                Some("（主角站在门厅冷静对峙、旧宅门厅、主角、5秒、中景、静止、盯住来人、冷峻压迫、室内冷光、你终于来了、风声回响、A12）"),
                Some("5s"),
            )]),
        );

        let selection = prompts.get(&12).expect("storyboard 12 prompt");
        assert_eq!(selection.as_deref(), Some("avoid frantic mood"));
        assert_eq!(selection.budget_tier, "lean");
    }

    #[test]
    fn review_fragment_is_irrelevant_to_dialogue_free_storyboard() {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角贴墙前行".into()),
            video_desc: Some("（主角贴墙前行、旧宅走廊、主角、5秒、近景、稳定跟拍、贴墙前行、压迫、冷调逆光、无台词、风声回响、A12）".into()),
            duration: Some("5".into()),
        };

        assert!(review_fragment_is_irrelevant_to_storyboard(
            "avoid lip-sync mismatch",
            Some(&storyboard_row),
        ));
        assert!(!review_fragment_is_irrelevant_to_storyboard(
            "avoid flicker or motion jitter",
            Some(&storyboard_row),
        ));
    }

    #[test]
    fn storyboard_dialogue_is_empty_recognizes_silent_markers() {
        assert!(storyboard_dialogue_is_empty("无台词"));
        assert!(storyboard_dialogue_is_empty("No dialogue"));
        assert!(storyboard_dialogue_is_empty("silent"));
        assert!(!storyboard_dialogue_is_empty("你终于来了"));
    }

    #[test]
    fn build_storyboard_negative_prompts_drops_lip_sync_for_silent_storyboard_only() {
        let prompts = build_storyboard_negative_prompts(
            &[12, 13],
            &[QualityReviewSeedRow {
                target_type: Some("video".into()),
                target_id: None,
                bad_case_category: Some("dialogue_issue".into()),
                comments: None,
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[
                (
                    12,
                    Some("主角贴墙前行"),
                    Some("（主角贴墙前行、旧宅走廊、主角、5秒、近景、稳定跟拍、贴墙前行、压迫、冷调逆光、无台词、风声回响、A12）"),
                    Some("5"),
                ),
                (
                    13,
                    Some("主角低声说你终于来了"),
                    Some("（主角低声说你终于来了、旧宅门口、主角、5秒、近景、稳定跟拍、停步低声说出、压迫、冷调逆光、你终于来了、风声压过呼吸声、A13）"),
                    Some("5"),
                ),
            ]),
        );

        assert_eq!(prompts.get(&12).and_then(|value| value.as_deref()), None);
        assert_eq!(
            prompts.get(&13).and_then(|value| value.as_deref()),
            Some("avoid lip-sync mismatch")
        );
    }

    #[test]
    fn build_storyboard_negative_prompts_keeps_storyboard_memory_axis_when_global_review_is_higher_value(
    ) {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[
                QualityReviewSeedRow {
                    target_type: Some("output".into()),
                    target_id: None,
                    bad_case_category: Some("visual_error".into()),
                    comments: Some("明显闪烁，手部也会变形".into()),
                },
                QualityReviewSeedRow {
                    target_type: Some("output".into()),
                    target_id: None,
                    bad_case_category: Some("character_break".into()),
                    comments: Some("角色服装和脸都会漂移".into()),
                },
            ],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid oppressive or frantic mood, avoid flat cold lighting".into(),
            }],
            &[],
            &HashMap::new(),
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value| value.as_deref())
            .expect("storyboard 12 prompt");

        assert!(prompt.contains("avoid flat cold lighting"));
        assert!(prompt.contains("avoid face distortion, identity drift, costume drift"));
        assert!(prompt.contains("avoid warped anatomy, blur, flicker"));
        assert!(prompt.len() <= VIDEO_NEGATIVE_PROMPT_MAX_CHARS);
    }

    #[test]
    fn build_storyboard_negative_prompts_prioritizes_higher_value_constraints_under_budget() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[
                QualityReviewSeedRow {
                    target_type: Some("storyboard".into()),
                    target_id: Some("12".into()),
                    bad_case_category: Some("visual_error".into()),
                    comments: Some("明显闪烁，手部也会变形".into()),
                },
                QualityReviewSeedRow {
                    target_type: Some("storyboard".into()),
                    target_id: Some("12".into()),
                    bad_case_category: Some("character_break".into()),
                    comments: Some("角色服装和脸都会漂移".into()),
                },
            ],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid oppressive or frantic mood, avoid flat cold lighting".into(),
            }],
            &[],
            &HashMap::new(),
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value| value.as_deref())
            .expect("storyboard 12 prompt");

        assert!(prompt.contains("avoid face distortion, identity drift, costume drift"));
        assert!(prompt.contains("avoid warped anatomy, blur, flicker"));
        assert!(prompt.contains("avoid flat cold lighting"));
        assert!(!prompt.contains("avoid oppressive or frantic mood"));
        assert!(prompt.len() <= VIDEO_NEGATIVE_PROMPT_MAX_CHARS);
    }

    #[test]
    fn compact_review_fragments_against_rejected_memory_drops_covered_global_tail_only() {
        let review_fragments = vec![
            "avoid flicker".to_string(),
            "avoid harsh backlight silhouette".to_string(),
            "avoid face drift or costume inconsistency".to_string(),
        ];
        let rejected_fragments = vec![
            "avoid flicker or motion jitter".to_string(),
            "avoid flat cold lighting".to_string(),
        ];

        assert_eq!(
            compact_review_fragments_against_rejected_memory(review_fragments, &rejected_fragments),
            vec![
                "avoid harsh backlight silhouette".to_string(),
                "avoid face drift or costume inconsistency".to_string()
            ]
        );
    }

    #[test]
    fn compact_review_fragments_against_rejected_memory_trims_storyboard_mismatch_bundle_to_new_axis(
    ) {
        let review_fragments = vec!["avoid extra shot changes or wrong framing".to_string()];
        let rejected_fragments =
            vec!["avoid extreme camera angle or overly tight close-up framing".to_string()];

        assert_eq!(
            compact_review_fragments_against_rejected_memory(review_fragments, &rejected_fragments),
            vec!["avoid unnecessary shot changes".to_string()]
        );
    }

    #[test]
    fn compact_review_fragments_against_rejected_memory_trims_pacing_bundle_to_new_axis() {
        let review_fragments = vec!["avoid rushed or jerky motion".to_string()];
        let rejected_fragments = vec!["avoid flicker or motion jitter".to_string()];

        assert_eq!(
            compact_review_fragments_against_rejected_memory(review_fragments, &rejected_fragments),
            vec!["avoid rushed motion".to_string()]
        );
    }

    #[test]
    fn build_storyboard_negative_prompts_keeps_global_tail_only_when_it_adds_new_axis() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[
                QualityReviewSeedRow {
                    target_type: Some("output".into()),
                    target_id: None,
                    bad_case_category: None,
                    comments: Some("闪烁明显".into()),
                },
                QualityReviewSeedRow {
                    target_type: Some("output".into()),
                    target_id: None,
                    bad_case_category: None,
                    comments: Some("逆光太重".into()),
                },
            ],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=3 | avoid=avoid flicker or motion jitter, avoid flat cold lighting".into(),
            }],
            &[],
            &HashMap::new(),
        );

        assert_eq!(
            prompts.get(&12).and_then(|value| value.as_deref()),
            Some("avoid flicker or motion jitter, avoid flat cold lighting or harsh backlight silhouette")
        );
    }

    #[test]
    fn selected_video_style_can_suppress_conflicting_review_fragments() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("近景太近，情绪太冷太压迫，逆光太重".into()),
            }],
            &[],
            &[AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | promptSeed=seed000000001 | style=镜头近景，情绪冷峻压迫，光影冷调逆光 | note=镜头近景，情绪冷峻压迫，光影冷调逆光".into(),
            }],
            &storyboard_seed_rows(&[(
                12,
                Some("门厅对峙"),
                Some("（主角对峙、旧宅门厅、主角、5秒、近景、静止、盯住来人、冷峻压迫、冷调逆光、、、A12）"),
                Some("5s"),
            )]),
        );

        let prompt = prompts.get(&12).and_then(|value| value.as_deref());
        assert_eq!(prompt, None);
    }

    #[test]
    fn storyboard_context_can_suppress_conflicting_review_fragments_without_style_memory() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("近景太近，情绪太冷太压迫，逆光太重".into()),
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("门厅对峙"),
                Some("（主角对峙、旧宅门厅、主角、5秒、近景、静止、盯住来人、冷峻压迫、冷调逆光、、、A12）"),
                Some("5s"),
            )]),
        );

        let prompt = prompts.get(&12).and_then(|value| value.as_deref());
        assert_eq!(prompt, None);
    }

    #[test]
    fn filter_selected_rows_for_subject_skips_other_subject_exact_memory() {
        let filtered = filter_selected_rows_for_subject(
            &[
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | style=镜头近景，情绪冷峻压迫".into(),
                },
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | style=表演抬眼停顿，语气轻声克制".into(),
                },
                AgentMemoryRow {
                    name: "script_video_style_memory".into(),
                    content: "style=镜头稳定跟拍，情绪冷峻压迫".into(),
                },
            ],
            &["林晚".to_string(), "晚晚".to_string()],
        );

        assert_eq!(filtered.len(), 2);
        assert!(filtered.iter().any(|row| {
            row.name == "selected_video_memory" && row.content.contains("subject=林晚")
        }));
        assert!(filtered
            .iter()
            .any(|row| row.name == "script_video_style_memory"));
        assert!(!filtered.iter().any(|row| {
            row.name == "selected_video_memory" && row.content.contains("subject=顾承泽")
        }));
    }

    #[test]
    fn script_video_style_summary_can_suppress_conflicting_review_fragments() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("情绪太冷太压迫，逆光太重".into()),
            }],
            &[],
            &[AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content:
                    "style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"
                        .into(),
            }],
            &HashMap::new(),
        );

        let prompt = prompts.get(&12).and_then(|value| value.as_deref());
        assert_eq!(prompt, None);
    }

    #[test]
    fn script_video_style_summary_with_ascii_delimiters_can_suppress_conflicting_review_fragments()
    {
        let storyboard_rows = storyboard_seed_rows(&[(
            12,
            Some("门厅对峙"),
            Some("（主角对峙、旧宅门厅、主角、5秒、近景、静止、盯住来人、冷峻压迫、冷调逆光、、、A12）"),
            Some("5s"),
        )]);
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("情绪太冷太压迫，逆光太重".into()),
            }],
            &[],
            &[AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content:
                    "style=镜头稳定跟拍, 情绪冷峻压迫; 光影冷调逆光 | note=镜头稳定跟拍, 情绪冷峻压迫; 光影冷调逆光"
                        .into(),
            }],
            &storyboard_rows,
        );

        let prompt = prompts.get(&12).and_then(|value| value.as_deref());
        assert_eq!(prompt, None);
    }

    #[test]
    fn script_video_style_summary_can_suppress_conflicting_rejected_fragments() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood"
                        .into(),
            }],
            &[AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content:
                    "style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"
                        .into(),
            }],
            &HashMap::new(),
        );

        let prompt = prompts.get(&12).and_then(|value| value.as_deref());
        assert_eq!(prompt, None);
    }

    #[test]
    fn rejected_fragments_keep_non_conflicting_constraints_under_style_memory() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting, avoid face drift or costume inconsistency"
                        .into(),
            }],
            &[AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content:
                    "style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"
                        .into(),
            }],
            &HashMap::new(),
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value| value.as_deref())
            .expect("storyboard 12 prompt");
        assert_eq!(prompt, "avoid face drift or costume inconsistency");
    }

    #[test]
    fn selected_video_style_does_not_suppress_non_conflicting_review_fragments() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: Some("character_break".into()),
                comments: Some("角色脸不稳定".into()),
            }],
            &[],
            &[AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | promptSeed=seed000000001 | style=镜头近景，情绪冷峻压迫，光影冷调逆光 | note=镜头近景，情绪冷峻压迫，光影冷调逆光".into(),
            }],
            &storyboard_seed_rows(&[(
                12,
                Some("门厅对峙"),
                Some("（主角对峙、旧宅门厅、主角、5秒、近景、静止、盯住来人、冷峻压迫、冷调逆光、、、A12）"),
                Some("5s"),
            )]),
        );
        let prompt = prompts
            .get(&12)
            .and_then(|value| value.as_deref())
            .expect("storyboard 12 prompt");
        assert!(prompt.contains("avoid face distortion, identity drift, costume drift"));
    }

    #[test]
    fn script_style_summary_does_not_suppress_conflicting_rejected_fragments_when_storyboard_context_mismatches(
    ) {
        let storyboard_rows = storyboard_seed_rows(&[(
            12,
            Some("女主在雨夜街口停下"),
            Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、静止镜头、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）"),
            Some("5s"),
        )]);
        let prompt_seed = storyboard_rows
            .get(&12)
            .and_then(storyboard_prompt_seed)
            .expect("storyboard prompt seed");
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: format!(
                    "storyboardIds=12 | promptSeed={prompt_seed} | rejectionCount=2 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood"
                ),
            }],
            &[AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=4 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            }],
            &storyboard_rows,
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value| value.as_deref())
            .expect("storyboard 12 prompt");
        assert!(prompt.contains("avoid oppressive or frantic mood"));
    }

    #[test]
    fn project_style_summary_still_suppresses_conflicting_review_when_context_matches() {
        let storyboard_rows = storyboard_seed_rows(&[(
            12,
            Some("门厅对峙"),
            Some("（主角对峙、旧宅门厅、主角、5秒、中景、稳定跟拍、逼近对手、冷峻压迫、冷调逆光、、、A12）"),
            Some("5s"),
        )]);
        let prompt_seed = storyboard_rows
            .get(&12)
            .and_then(storyboard_prompt_seed)
            .expect("storyboard prompt seed");
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: format!(
                    "storyboardIds=12 | promptSeed={prompt_seed} | rejectionCount=2 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood"
                ),
            }],
            &[AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            }],
            &storyboard_rows,
        );

        let prompt = prompts.get(&12).and_then(|value| value.as_deref());
        assert_eq!(prompt, None);
    }

    #[test]
    fn review_fragment_conflict_filter_is_limited_to_exact_selected_style_signals() {
        assert!(review_fragment_conflicts_with_selected_style(
            "avoid overly tight close-up framing",
            Some("镜头近景，情绪冷峻压迫，光影冷调逆光"),
            None,
        ));
        assert!(!review_fragment_conflicts_with_selected_style(
            "avoid wrong setting details",
            Some("镜头近景，情绪冷峻压迫，光影冷调逆光"),
            None,
        ));
    }

    #[test]
    fn infer_video_provider_defaults_to_runway() {
        assert_eq!(infer_video_provider("gen-2"), "runway");
        assert_eq!(infer_video_provider("kling-v1"), "kling");
        assert_eq!(infer_video_provider("pika-1.5"), "pika");
    }

    #[test]
    fn compact_video_ratio_recognizes_common_formats() {
        assert_eq!(compact_video_ratio("vertical 9:16"), Some("9:16".into()));
        assert_eq!(compact_video_ratio("horizontal"), Some("16:9".into()));
        assert_eq!(compact_video_ratio("square 1:1"), Some("1:1".into()));
        assert_eq!(compact_video_ratio(""), None);
    }

    #[test]
    fn rejected_negative_memory_fetch_limit_scales_up_to_keep_window() {
        assert_eq!(rejected_negative_memory_fetch_limit(0), 8);
        assert_eq!(rejected_negative_memory_fetch_limit(1), 8);
        assert_eq!(rejected_negative_memory_fetch_limit(5), 10);
        assert_eq!(rejected_negative_memory_fetch_limit(9), 12);
    }

    #[test]
    fn selected_memory_fetch_limit_reserves_room_for_summary_rows() {
        assert_eq!(selected_memory_fetch_limit(0), 8);
        assert_eq!(selected_memory_fetch_limit(1), 8);
        assert_eq!(selected_memory_fetch_limit(4), 10);
        assert_eq!(selected_memory_fetch_limit(8), 14);
    }
}
