use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};

use super::{VideoListBody, VideoListResponse};
use crate::error::{bad_request_i18n, ApiError};
use crate::scope::http::require_authenticated_user;
use crate::state::AppState;
use crate::{projects::routes::common::require_project_workspace_member_scope, scope};

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/get-video-list",
    operation_id = "postProductionWorkbenchGetVideoListV1",
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
pub(in crate::production) async fn post_workbench_get_video_list(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<VideoListBody>,
) -> Result<JsonResponse<VideoListResponse>, ApiError> {
    let uid = require_authenticated_user(&state, &headers)?;
    let pool = state.require_pool()?;
    let project_id = if let Some(project_uuid) = body.project_uuid {
        let _scope = require_project_workspace_member_scope(&state, uid, project_uuid).await?;
        project_uuid
    } else {
        let project_numeric_id = body.project_id.ok_or_else(|| {
            bad_request_i18n(
                "projectId or projectUuid is required",
                "projectId 或 projectUuid 至少需要提供一个",
            )
        })?;
        scope::owned_project_id_by_numeric(pool, uid, project_numeric_id)
            .await
            .map_err(|e| e.into_api_error())?
    };

    let limit = body.limit.map(|l| l.clamp(1, 100)).unwrap_or(50);
    let offset = body.offset.unwrap_or(0).max(0);

    let videos = sqlx::query_as(
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
        WHERE sc.project_id = $1
          AND sb.file_path IS NOT NULL
          AND (sb.file_path LIKE '%.mp4' OR sb.file_path LIKE '%.mov' OR sb.file_path LIKE '%.webm')
          AND ($2::int4 IS NULL OR sb.track_id = $2)
        ORDER BY sb.created_at DESC
        LIMIT $3 OFFSET $4
        "#,
    )
    .bind(project_id)
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
        WHERE sc.project_id = $1
          AND sb.file_path IS NOT NULL
          AND (sb.file_path LIKE '%.mp4' OR sb.file_path LIKE '%.mov' OR sb.file_path LIKE '%.webm')
          AND ($2::int4 IS NULL OR sb.track_id = $2)
        "#,
    )
    .bind(project_id)
    .bind(body.track_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(VideoListResponse { videos, total }))
}
