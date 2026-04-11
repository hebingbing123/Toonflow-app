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

    let owned_count = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND s.numeric_id = $3
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.script_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if owned_count == 0 {
        return Err(ApiError::NotFound);
    }

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
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND sc.numeric_id = $3
          AND sb.file_path IS NOT NULL
          AND (sb.file_path LIKE '%.mp4' OR sb.file_path LIKE '%.mov' OR sb.file_path LIKE '%.webm')
        ORDER BY sb.created_at DESC
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.script_id)
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
