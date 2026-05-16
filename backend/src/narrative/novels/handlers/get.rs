use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{validate_positive, ApiError};
use crate::projects::routes::common::require_project_workspace_member_scope;
use crate::state::AppState;

use super::super::dto::NovelRow;

async fn fetch_owned_novel_row(
    pool: &PgPool,
    project_id: Uuid,
    novel_numeric_id: i32,
) -> Result<NovelRow, ApiError> {
    validate_positive(novel_numeric_id, "numericId")?;

    let row = sqlx::query_as::<_, NovelRow>(
        r#"
        SELECT n.id, n.numeric_id, n.chapter_index, n.reel, n.chapter, n.chapter_data,
               n.event, n.event_state, n.error_reason, n.create_time_ms,
               n.metadata->>'intakeSource' AS intake_source,
               n.metadata->>'intakeSourceUrl' AS intake_source_url,
               n.metadata->>'intakeStatus' AS intake_status,
               n.metadata->>'intakeNote' AS intake_note
        FROM app_novel n
        INNER JOIN app_project p ON p.id = n.project_id
        WHERE p.id = $1
          AND n.numeric_id = $2
        "#,
    )
    .bind(project_id)
    .bind(novel_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(row)
}

pub(crate) async fn get_novel_for_project(
    State(state): State<AppState>,
    Path((project_id, novel_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<Json<NovelRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    require_project_workspace_member_scope(&state, uid, project_id).await?;
    let row = fetch_owned_novel_row(pool, project_id, novel_numeric_id).await?;
    Ok(Json(row))
}
