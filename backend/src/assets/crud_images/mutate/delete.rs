use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{validate_positive, ApiError};
use crate::state::AppState;

use super::super::super::crud::{
    require_asset_project_write_scope, resolve_owned_asset_id_for_project,
};

pub(in crate::assets) async fn delete_project_asset_image_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_numeric_id, image_id)): Path<(Uuid, i32, Uuid)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    validate_positive(asset_numeric_id, "numeric ids")?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    require_asset_project_write_scope(&state, uid, project_id).await?;

    let asset_id =
        resolve_owned_asset_id_for_project(pool, uid, project_id, asset_numeric_id).await?;

    let res = sqlx::query(
        r#"
        DELETE FROM app_asset_image
        WHERE id = $1 AND asset_id = $2
        "#,
    )
    .bind(image_id)
    .bind(asset_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}
