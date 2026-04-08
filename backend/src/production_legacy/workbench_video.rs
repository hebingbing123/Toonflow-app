use axum::{
    extract::{Json, State},
    http::HeaderMap,
    response::{IntoResponse, Response},
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use super::{VideoItem, WorkbenchGenerateVideoBody};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

pub(super) async fn post_workbench_generate_video(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchGenerateVideoBody>,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.script_id <= 0 || body.track_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId/scriptId/trackId must be positive integers".into(),
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
          AND p.legacy_id = $2
          AND s.legacy_id = $3
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

    Ok(axum::http::StatusCode::OK.into_response())
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct VideoListResponse {
    videos: Vec<VideoItem>,
    total: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct VideoListBody {
    project_id: i32,
    #[serde(default)]
    track_id: Option<i32>,
    #[serde(default)]
    limit: Option<i64>,
    #[serde(default)]
    offset: Option<i64>,
}

pub(super) async fn post_workbench_get_video_list(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<VideoListBody>,
) -> Result<JsonResponse<VideoListResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId must be a positive integer".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let limit = body.limit.map(|l| l.clamp(1, 100)).unwrap_or(50);
    let offset = body.offset.unwrap_or(0).max(0);

    let videos = sqlx::query_as::<_, VideoItem>(
        r#"
        SELECT
          sb.legacy_id AS id,
          sc.legacy_id AS script_id,
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
          AND p.legacy_id = $2
          AND sb.file_path IS NOT NULL
          AND (sb.file_path LIKE '%.mp4' OR sb.file_path LIKE '%.mov' OR sb.file_path LIKE '%.webm')
          AND ($3::int4 IS NULL OR sb.track_id = $3)
        ORDER BY sb.created_at DESC
        LIMIT $4 OFFSET $5
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.track_id)
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let total: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND sb.file_path IS NOT NULL
          AND (sb.file_path LIKE '%.mp4' OR sb.file_path LIKE '%.mov' OR sb.file_path LIKE '%.webm')
          AND ($3::int4 IS NULL OR sb.track_id = $3)
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.track_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(VideoListResponse { videos, total }))
}
