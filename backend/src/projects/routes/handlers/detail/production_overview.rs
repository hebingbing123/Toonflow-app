//! 项目生产概览聚合（MP-W5 / A3）：就绪分镜、进行中的生成任务、坏例数。
//!
//! **就绪分镜**判定与 **`GET …/short-video-readiness`** 一致（见 `short_video_readiness.rs`）。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::types::ProjectProductionOverviewResponse;

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/production-overview",
    operation_id = "getProjectProductionOverviewByProjectIdV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    responses(
        (status = 200, description = "OK", body = ProjectProductionOverviewResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_production_overview_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<ProjectProductionOverviewResponse>, ApiError> {
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

    let total_storyboard_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        WHERE sc.project_id = $1
        "#,
    )
    .bind(resolved_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let ready_storyboard_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        WHERE sc.project_id = $1
          AND (sb.sb_index IS NOT NULL)
          AND (
            TRIM(COALESCE(sb.prompt, '')) <> ''
            OR TRIM(COALESCE(sb.video_desc, '')) <> ''
          )
          AND (TRIM(COALESCE(sb.file_path, '')) <> '')
          AND (
            TRIM(COALESCE(sb.metadata #>> '{shortVideo,candidateStatus}', '')) <> 'pending'
          )
          AND NOT EXISTS (
            SELECT 1
            FROM app_generation_job j
            WHERE j.owner_user_id = $2
              AND j.status IN ('queued', 'running')
              AND j.payload ? 'storyboard_numeric_id'
              AND (j.payload->>'storyboard_numeric_id') ~ '^[0-9]+$'
              AND (j.payload->>'storyboard_numeric_id')::int = sb.numeric_id
          )
        "#,
    )
    .bind(resolved_id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let running_generation_job_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(DISTINCT j.id)::bigint
        FROM app_generation_job j
        WHERE j.owner_user_id = $2
          AND j.status IN ('queued', 'running')
          AND (
            j.payload->>'project_numeric_id' = (
              SELECT numeric_id::text FROM app_project WHERE id = $1
            )
            OR EXISTS (
              SELECT 1
              FROM app_storyboard sb
              INNER JOIN app_script sc ON sc.id = sb.script_id
              WHERE sc.project_id = $1
                AND (j.payload->>'storyboard_numeric_id') IS NOT NULL
                AND (j.payload->>'storyboard_numeric_id')::int = sb.numeric_id
            )
          )
        "#,
    )
    .bind(resolved_id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let pending_review_bad_case_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_quality_review q
        WHERE q.user_id = $2
          AND q.is_bad_case = true
          AND q.project_id = (SELECT numeric_id FROM app_project WHERE id = $1)
        "#,
    )
    .bind(resolved_id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(ProjectProductionOverviewResponse {
        schema_version: 1,
        total_storyboard_count,
        ready_storyboard_count,
        running_generation_job_count,
        pending_review_bad_case_count,
    }))
}
