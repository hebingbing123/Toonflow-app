//! One-click batch orchestration for **candidate clip** generation (**L1** MP-W2 补充).
//!
//! Builds **`upload_data`** from **`app_storyboard`** (http(s) **`file_path`** + row prompt) and
//! defers to [`super::workbench_enqueue_video_jobs_from_body`] with defaults from
//! [`super::short_video_config::load_storyboard_generation_config`] (B 节单一配置源)。

use axum::extract::{Json, State};
use axum::http::HeaderMap;
use axum::Json as JsonResponse;
use serde::{Deserialize, Serialize};
use sqlx::{FromRow, PgPool};
use std::collections::HashSet;
use uuid::Uuid;

use crate::error::ApiError;
use crate::production::types::{GenerateVideoUploadItem, WorkbenchGenerateVideoBody};
use crate::scope::http::require_owned_numeric_script_scope;
use crate::scope::OwnedScriptScope;
use crate::state::AppState;

use super::short_video_config::load_storyboard_generation_config;
use super::{workbench_enqueue_video_jobs_from_body, WorkbenchGenerateVideoResponse};

#[derive(Debug, Clone, FromRow)]
struct CandidateStoryRow {
    numeric_id: i32,
    file_path: Option<String>,
    prompt: Option<String>,
    state: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct BatchGenerateCandidateClipsBody {
    pub project_id: i32,
    pub script_id: i32,
    #[serde(default)]
    pub track_id: Option<i32>,
    #[serde(default)]
    pub storyboard_numeric_ids: Option<Vec<i32>>,
    #[serde(default)]
    pub prompt: Option<String>,
    #[serde(default)]
    pub negative_prompt: Option<String>,
    #[serde(default)]
    pub model: Option<String>,
    #[serde(default)]
    pub mode: Option<String>,
    #[serde(default)]
    pub resolution: Option<String>,
    #[serde(default)]
    pub duration: Option<i32>,
    #[serde(default)]
    pub audio: Option<bool>,
    /// Skip shots already in **`生成中`** to avoid stacking duplicate jobs.
    #[serde(default = "default_true_skip_in_flight")]
    pub skip_in_flight_storyboards: bool,
}

#[inline]
fn default_true_skip_in_flight() -> bool {
    true
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct BatchSkippedStoryboard {
    pub storyboard_numeric_id: i32,
    pub reason: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct BatchCandidateClipDefaultsApplied {
    pub track_id: i32,
    pub model: String,
    pub mode: String,
    pub resolution: String,
    pub duration: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct BatchGenerateCandidateClipsResponse {
    pub skipped: Vec<BatchSkippedStoryboard>,
    pub applied_defaults: BatchCandidateClipDefaultsApplied,
    #[serde(flatten)]
    pub generation: WorkbenchGenerateVideoResponse,
}

#[inline]
fn resolution_from_video_ratio(video_ratio: Option<&str>) -> &'static str {
    match video_ratio {
        Some("9:16") => "1080x1920",
        Some("16:9") => "1920x1080",
        Some("1:1") => "1080x1080",
        _ => "1920x1080",
    }
}

fn duration_from_project_strategy(strategy: Option<&str>) -> i32 {
    match strategy {
        Some("short") => 15,
        Some("medium") => 30,
        Some("long") => 60,
        _ => 30,
    }
}

#[inline]
fn trimmed_nonempty(s: Option<&str>) -> Option<String> {
    s.map(str::trim)
        .filter(|t| !t.is_empty())
        .map(str::to_string)
}

#[inline]
fn validate_reference_source(raw: Option<&String>) -> Result<String, &'static str> {
    let candidate = raw
        .map(|s| s.trim())
        .filter(|t| !t.is_empty())
        .ok_or("missing_reference_url")?;
    let parsed = reqwest::Url::parse(candidate).map_err(|_| "invalid_reference_url")?;
    match parsed.scheme() {
        "http" | "https" => Ok(candidate.to_string()),
        _ => Err("unsupported_reference_url_scheme"),
    }
}

async fn fetch_default_track_numeric_id(
    pool: &PgPool,
    project_id: Uuid,
    script_id: Uuid,
) -> Result<i32, ApiError> {
    let row = sqlx::query_scalar::<_, i32>(
        r#"
        SELECT numeric_id
        FROM app_video_track
        WHERE project_id = $1
          AND (script_id = $2 OR script_id IS NULL)
        ORDER BY
          CASE WHEN script_id = $2 THEN 0 ELSE 1 END,
          numeric_id ASC
        LIMIT 1
        "#,
    )
    .bind(project_id)
    .bind(script_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    row.ok_or_else(|| {
        ApiError::BadRequest(
            "no video track found for this script; create a production track before batch generation"
                .into(),
        )
    })
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/batch-generate-candidate-clips",
    operation_id = "postProductionWorkbenchBatchGenerateCandidateClipsV1",
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
pub(in crate::production) async fn post_workbench_batch_generate_candidate_clips(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchGenerateCandidateClipsBody>,
) -> Result<JsonResponse<BatchGenerateCandidateClipsResponse>, ApiError> {
    let BatchGenerateCandidateClipsBody {
        project_id,
        script_id,
        track_id: track_override,
        storyboard_numeric_ids,
        prompt,
        negative_prompt,
        model,
        mode,
        resolution,
        duration,
        audio,
        skip_in_flight_storyboards,
    } = body;

    let (user_id, pool, scope_row) =
        require_owned_numeric_script_scope(&state, &headers, project_id, script_id).await?;

    let resolved = resolve_batch_defaults(
        pool,
        &scope_row,
        BatchEnqueueParamOverrides {
            track_id: track_override,
            duration,
            model,
            mode,
            resolution,
            prompt_overlay: prompt,
        },
    )
    .await?;

    let filters: Option<HashSet<i32>> = storyboard_numeric_ids
        .filter(|v| !v.is_empty())
        .map(|v| v.into_iter().collect());

    let rows = sqlx::query_as::<_, CandidateStoryRow>(
        r#"
        SELECT numeric_id, file_path, prompt, state
        FROM app_storyboard
        WHERE script_id = $1
        ORDER BY sb_index ASC NULLS LAST, numeric_id ASC
        "#,
    )
    .bind(scope_row.script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut skipped = Vec::<BatchSkippedStoryboard>::new();
    let mut upload_data = Vec::<GenerateVideoUploadItem>::new();

    for row in rows {
        if let Some(ref set) = filters {
            if !set.contains(&row.numeric_id) {
                skipped.push(BatchSkippedStoryboard {
                    storyboard_numeric_id: row.numeric_id,
                    reason: "not_in_storyboard_numeric_ids_filter".into(),
                });
                continue;
            }
        }

        if skip_in_flight_storyboards && row.state.as_deref() == Some("生成中") {
            skipped.push(BatchSkippedStoryboard {
                storyboard_numeric_id: row.numeric_id,
                reason: "storyboard_already_generating".into(),
            });
            continue;
        }

        let source_url = match validate_reference_source(row.file_path.as_ref()) {
            Ok(u) => u,
            Err(reason) => {
                skipped.push(BatchSkippedStoryboard {
                    storyboard_numeric_id: row.numeric_id,
                    reason: reason.into(),
                });
                continue;
            }
        };

        let row_prompt = trimmed_nonempty(row.prompt.as_deref());
        if row_prompt.is_none() && resolved.prompt_overlay.is_empty() {
            skipped.push(BatchSkippedStoryboard {
                storyboard_numeric_id: row.numeric_id,
                reason: "missing_storyboard_prompt".into(),
            });
            continue;
        }

        upload_data.push(GenerateVideoUploadItem {
            id: row.numeric_id,
            sources: source_url,
            prompt: row_prompt,
            negative_prompt: None,
        });
    }

    if upload_data.is_empty() {
        return Err(ApiError::BadRequest(
            "no storyboards queued: every shot was skipped (need https reference frames, prompts, and an active track; or adjust filters / skipInFlightStoryboards)"
                .into(),
        ));
    }

    let workbench_body = WorkbenchGenerateVideoBody {
        project_id,
        script_id,
        upload_data,
        prompt: resolved.prompt_overlay.clone(),
        negative_prompt,
        model: resolved.model.clone(),
        mode: resolved.mode.clone(),
        resolution: resolved.resolution.clone(),
        duration: resolved.duration,
        audio,
        track_id: resolved.track_id,
    };

    let generation = workbench_enqueue_video_jobs_from_body(
        user_id,
        pool,
        &scope_row,
        workbench_body,
        Some(&headers),
    )
    .await?;

    Ok(JsonResponse(BatchGenerateCandidateClipsResponse {
        skipped,
        applied_defaults: BatchCandidateClipDefaultsApplied {
            track_id: resolved.track_id,
            model: resolved.model,
            mode: resolved.mode,
            resolution: resolved.resolution,
            duration: resolved.duration,
        },
        generation,
    }))
}

struct ResolvedBatchDefaults {
    track_id: i32,
    model: String,
    mode: String,
    resolution: String,
    duration: i32,
    prompt_overlay: String,
}

struct BatchEnqueueParamOverrides {
    track_id: Option<i32>,
    duration: Option<i32>,
    model: Option<String>,
    mode: Option<String>,
    resolution: Option<String>,
    prompt_overlay: Option<String>,
}

async fn resolve_batch_defaults(
    pool: &PgPool,
    scope_row: &OwnedScriptScope,
    overrides: BatchEnqueueParamOverrides,
) -> Result<ResolvedBatchDefaults, ApiError> {
    let pv_config = load_storyboard_generation_config(pool, scope_row.project_id).await?;
    let track_id = match overrides.track_id.filter(|t| *t > 0) {
        Some(tid) => tid,
        None => {
            fetch_default_track_numeric_id(pool, scope_row.project_id, scope_row.script_id).await?
        }
    };

    let duration = overrides
        .duration
        .filter(|d| *d > 0)
        .unwrap_or_else(|| duration_from_project_strategy(pv_config.duration_strategy.as_deref()));

    let model = trimmed_nonempty(overrides.model.as_deref())
        .or_else(|| trimmed_nonempty(pv_config.video_model.as_deref()))
        .unwrap_or_else(|| "kling-v1".to_string());

    let mode = trimmed_nonempty(overrides.mode.as_deref())
        .or_else(|| trimmed_nonempty(pv_config.mode.as_deref()))
        .unwrap_or_else(|| "animated.short_drama".to_string());

    let resolution = trimmed_nonempty(overrides.resolution.as_deref()).unwrap_or_else(|| {
        resolution_from_video_ratio(pv_config.video_ratio.as_deref()).to_string()
    });

    let prompt_overlay = trimmed_nonempty(overrides.prompt_overlay.as_deref()).unwrap_or_default();

    Ok(ResolvedBatchDefaults {
        track_id,
        model,
        mode,
        resolution,
        duration,
        prompt_overlay,
    })
}
