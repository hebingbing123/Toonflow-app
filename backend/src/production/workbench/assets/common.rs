use axum::http::HeaderMap;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::scope::http::require_owned_numeric_script_scope;
use crate::state::AppState;

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

pub(super) async fn require_owned_normalized_assets_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_id: i32,
    script_id: i32,
    asset_ids: &[i32],
) -> Result<(Uuid, &'a PgPool, Uuid, Vec<i32>), ApiError> {
    let uniq = normalize_asset_ids(asset_ids)?;
    let (uid, pool, scope_row) =
        require_owned_numeric_script_scope(state, headers, project_id, script_id).await?;
    ensure_assets_linked_to_script(pool, uid, project_id, scope_row.script_id, &uniq).await?;
    Ok((uid, pool, scope_row.script_id, uniq))
}
