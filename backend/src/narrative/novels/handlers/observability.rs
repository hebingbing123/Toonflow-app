use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::JOB_KIND_NOVEL_CRAWL_IMPORT_BATCH;
use crate::projects::routes::common::require_project_workspace_member_scope;
use crate::state::AppState;

use super::super::dto::{
    NovelCrawlAuditSampleRow, NovelCrawlJobStatusCount, NovelCrawlObservabilityResponse,
    NovelIntakeSourceCount, NovelIntakeStatusCount,
};

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/novels/crawl-observability",
    operation_id = "getProjectNovelCrawlObservabilityByProjectIdV1",
    tag = "novels",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    responses(
        (status = 200, description = "OK", body = NovelCrawlObservabilityResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_novel_crawl_observability(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
) -> Result<Json<NovelCrawlObservabilityResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_workspace_member_scope(&state, uid, project_id).await?;

    let total_chapters: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_novel n
        WHERE n.project_id = $1
        "#,
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let intake_sources = sqlx::query_as::<_, NovelIntakeSourceCount>(
        r#"
        SELECT (n.metadata->>'intakeSource')::text as intake_source,
               COUNT(*)::bigint as chapter_count
        FROM app_novel n
        WHERE n.project_id = $1
        GROUP BY intake_source
        ORDER BY chapter_count DESC
        "#,
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let intake_statuses = sqlx::query_as::<_, NovelIntakeStatusCount>(
        r#"
        SELECT (n.metadata->>'intakeStatus')::text as intake_status,
               COUNT(*)::bigint as chapter_count
        FROM app_novel n
        WHERE n.project_id = $1
        GROUP BY intake_status
        ORDER BY chapter_count DESC
        "#,
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let recent_server_imports = sqlx::query_as::<_, NovelCrawlAuditSampleRow>(
        r#"
        SELECT n.numeric_id,
               n.metadata->>'intakeSourceUrl' as intake_source_url,
               n.metadata->>'intakeNote' as intake_note,
               n.create_time_ms
        FROM app_novel n
        WHERE n.project_id = $1
          AND n.metadata->>'intakeSource' = 'crawler_server'
        ORDER BY n.numeric_id DESC
        LIMIT 20
        "#,
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let crawl_job_statuses = sqlx::query_as::<_, NovelCrawlJobStatusCount>(
        r#"
        SELECT status::text as status, COUNT(*)::bigint as job_count
        FROM app_generation_job
        WHERE kind = $1
          AND payload->>'project_id' = $2
        GROUP BY status
        ORDER BY job_count DESC
        "#,
    )
    .bind(JOB_KIND_NOVEL_CRAWL_IMPORT_BATCH)
    .bind(project_id.to_string())
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(NovelCrawlObservabilityResponse {
        total_chapters,
        intake_sources,
        intake_statuses,
        recent_server_imports,
        crawl_job_statuses,
    }))
}
