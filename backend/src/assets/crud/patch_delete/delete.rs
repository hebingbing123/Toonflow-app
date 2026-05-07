//! `DELETE` project asset by stable numeric ids.

use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
};
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::resolve::ensure_owned_project_pk;

async fn delete_project_asset_inner(
    pool: &PgPool,
    project_id: Uuid,
    asset_numeric_id: i32,
) -> Result<StatusCode, ApiError> {
    if asset_numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric ids must be positive".into()));
    }

    let res = sqlx::query(
        r#"
        DELETE FROM app_asset a
        USING app_project p
        WHERE a.project_id = p.id
          AND p.id = $1
          AND a.numeric_id = $2
        "#,
    )
    .bind(project_id)
    .bind(asset_numeric_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}

pub(crate) async fn delete_project_asset_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    ensure_owned_project_pk(pool, uid, project_id).await?;
    delete_project_asset_inner(pool, project_id, asset_numeric_id).await
}
