use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use super::super::VideoItem;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{JobRow, JOB_KIND_VIDEO_GENERATE};
use crate::scope;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct GenerateVideoPromptBody {
    project_id: i32,
    script_id: i32,
    #[serde(default)]
    #[allow(dead_code)]
    image_url: Option<String>,
    #[serde(default)]
    description: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct GenerateVideoPromptResponse {
    prompt: String,
    model: String,
    duration: i32,
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
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.script_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and scriptId must be positive integers".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    scope::owned_script_scope(pool, uid, body.project_id, body.script_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let prompt = if let Some(desc) = body.description {
        format!(
            "Generate a cinematic video scene: {}. High quality, smooth motion, professional lighting.",
            desc
        )
    } else {
        "Generate a cinematic video scene with smooth motion, professional lighting, and high quality visuals.".to_string()
    };

    Ok(JsonResponse(GenerateVideoPromptResponse {
        prompt,
        model: "runway-gen-2".to_string(),
        duration: 5,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct GetGenerateDataBody {
    project_id: i32,
    script_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct GetGenerateDataResponse {
    project_id: i32,
    script_id: i32,
    generated_videos: Vec<VideoItem>,
    generating_jobs: Vec<JobRow>,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/get-generate-data",
    operation_id = "postProductionWorkbenchGetGenerateDataV1",
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
pub(in crate::production) async fn post_workbench_get_generate_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetGenerateDataBody>,
) -> Result<JsonResponse<GetGenerateDataResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.script_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and scriptId must be positive integers".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let scope = scope::owned_script_scope(pool, uid, body.project_id, body.script_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let generated_videos = sqlx::query_as::<_, VideoItem>(
        r#"
        SELECT
          sb.numeric_id AS id,
          sc.numeric_id AS script_id,
          sb.prompt,
          sb.file_path AS video_url,
          sb.duration,
          sb.state,
          sb.track_id,
          sb.created_at
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        WHERE sb.script_id = $1
          AND sb.file_path IS NOT NULL
          AND (sb.file_path LIKE '%.mp4' OR sb.file_path LIKE '%.mov' OR sb.file_path LIKE '%.webm')
        ORDER BY sb.created_at DESC
        "#,
    )
    .bind(scope.script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let generating_jobs = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT 0 AS numeric_task_id, id, owner_user_id, kind, status, payload, result, NULL AS error_message, NULL AS idempotency_key, NULL AS claimed_by, created_at, updated_at
        FROM app_job
        WHERE owner_user_id = $1
          AND kind = $2
          AND status IN ('queued', 'running')
        ORDER BY created_at DESC
        LIMIT 10
        "#,
    )
    .bind(uid)
    .bind(JOB_KIND_VIDEO_GENERATE)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(GetGenerateDataResponse {
        project_id: body.project_id,
        script_id: body.script_id,
        generated_videos,
        generating_jobs,
    }))
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
    let _uid = require_user_uuid(&state, &headers)?;

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
