use axum::http::HeaderMap;
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::scope::{self, OwnedScriptScope};
use crate::state::AppState;

pub(super) fn validate_project_and_script_ids(
    project_id: i32,
    script_id: i32,
) -> Result<(), ApiError> {
    if project_id <= 0 || script_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and scriptId must be positive integers".into(),
        ));
    }
    Ok(())
}

pub(super) fn normalize_asset_ids(asset_ids: &[i32]) -> Result<Vec<i32>, ApiError> {
    if asset_ids.is_empty() {
        return Err(ApiError::BadRequest("assetIds must not be empty".into()));
    }
    if asset_ids.iter().any(|id| *id <= 0) {
        return Err(ApiError::BadRequest(
            "assetIds must be positive integers".into(),
        ));
    }

    let mut uniq = asset_ids.to_vec();
    uniq.sort_unstable();
    uniq.dedup();
    Ok(uniq)
}

pub(super) async fn require_owned_script_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_id: i32,
    script_id: i32,
) -> Result<(Uuid, &'a PgPool, OwnedScriptScope), ApiError> {
    let uid = require_user_uuid(state, headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let scope_row = scope::owned_script_scope(pool, uid, project_id, script_id)
        .await
        .map_err(|e| e.into_api_error())?;
    Ok((uid, pool, scope_row))
}

pub(super) async fn ensure_assets_linked_to_script(
    pool: &PgPool,
    uid: Uuid,
    project_id: i32,
    script_id: Uuid,
    asset_ids: &[i32],
) -> Result<(), ApiError> {
    let linked: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(DISTINCT a.numeric_id)::bigint
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id AND sa.script_id = $3
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND a.numeric_id = ANY($4::int4[])
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(script_id)
    .bind(asset_ids)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if linked != asset_ids.len() as i64 {
        return Err(ApiError::NotFound);
    }

    Ok(())
}
