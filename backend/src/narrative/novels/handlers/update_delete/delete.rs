use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
};
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{validate_positive, ApiError};
use crate::projects::routes::common::require_project_write_scope;
use crate::state::AppState;

async fn delete_novel_inner(
    pool: &PgPool,
    project_id: Uuid,
    novel_numeric_id: i32,
) -> Result<StatusCode, ApiError> {
    validate_positive(novel_numeric_id, "numericId")?;

    let res = sqlx::query(
        r#"
        DELETE FROM app_novel n
        USING app_project p
        WHERE n.project_id = p.id
          AND p.id = $1
          AND n.numeric_id = $2
        "#,
    )
    .bind(project_id)
    .bind(novel_numeric_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}

pub(crate) async fn delete_novel_for_project(
    State(state): State<AppState>,
    Path((project_id, novel_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    require_project_write_scope(&state, uid, project_id).await?;
    delete_novel_inner(pool, project_id, novel_numeric_id).await
}
