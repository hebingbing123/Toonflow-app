//! 项目维度统计（剧本、分镜、角色、小说、视频任务等）。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::types::ProjectStatsResponse;

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/stats",
    operation_id = "getProjectStatsByProjectIdV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    responses(
        (status = 200, description = "OK", body = ProjectStatsResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_stats_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<ProjectStatsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let row: Option<(Uuid,)> = sqlx::query_as(
        r#"
        SELECT id
        FROM app_project
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(project_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let (resolved_id,) = row.ok_or(ApiError::NotFound)?;

    let script_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_script
        WHERE project_id = $1
        "#,
    )
    .bind(resolved_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let storyboard_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_storyboard sb
        INNER JOIN app_script s ON sb.script_id = s.id
        WHERE s.project_id = $1
        "#,
    )
    .bind(resolved_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let role_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_asset
        WHERE project_id = $1 AND asset_type = 'role'
        "#,
    )
    .bind(resolved_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let novel_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_novel
        WHERE project_id = $1
        "#,
    )
    .bind(resolved_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let video_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_generation_job
        WHERE owner_user_id = $2
          AND status = 'succeeded'
          AND (kind ILIKE '%video%' OR kind ILIKE '%workbench%')
          AND payload->>'project_numeric_id' = (
              SELECT numeric_id::text FROM app_project WHERE id = $1
          )
        "#,
    )
    .bind(resolved_id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(ProjectStatsResponse {
        script_count,
        storyboard_count,
        role_count,
        novel_count,
        video_count,
    }))
}
