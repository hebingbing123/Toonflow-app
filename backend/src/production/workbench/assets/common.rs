use axum::http::HeaderMap;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::{bad_request_i18n, ApiError};
use crate::scope::http::{require_script_read_scope_ref, require_script_write_scope_ref};
use crate::state::AppState;

pub(super) fn normalize_asset_ids(asset_ids: &[i32]) -> Result<Vec<i32>, ApiError> {
    if asset_ids.is_empty() {
        return Err(bad_request_i18n(
            "assetIds must not be empty",
            "assetIds 不能为空",
        ));
    }
    if asset_ids.iter().any(|id| *id <= 0) {
        return Err(bad_request_i18n(
            "assetIds must be positive integers",
            "assetIds 必须是正整数",
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
        WHERE p.numeric_id = $2
          AND a.numeric_id = ANY($4::int4[])
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $1
          )
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

pub(super) async fn require_owned_normalized_assets_scope_ref<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_id: Option<i32>,
    project_uuid: Option<Uuid>,
    script_id: i32,
    asset_ids: &[i32],
) -> Result<(Uuid, &'a PgPool, i32, Uuid, Vec<i32>), ApiError> {
    let uniq = normalize_asset_ids(asset_ids)?;
    let (uid, pool, scope_row) =
        require_script_read_scope_ref(state, headers, project_id, project_uuid, script_id).await?;
    ensure_assets_linked_to_script(
        pool,
        uid,
        scope_row.project_numeric_id,
        scope_row.script_id,
        &uniq,
    )
    .await?;
    Ok((
        uid,
        pool,
        scope_row.project_numeric_id,
        scope_row.script_id,
        uniq,
    ))
}

pub(super) async fn require_owned_normalized_assets_write_scope_ref<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_id: Option<i32>,
    project_uuid: Option<Uuid>,
    script_id: i32,
    asset_ids: &[i32],
) -> Result<(Uuid, &'a PgPool, i32, Uuid, Vec<i32>), ApiError> {
    let uniq = normalize_asset_ids(asset_ids)?;
    let (uid, pool, scope_row) =
        require_script_write_scope_ref(state, headers, project_id, project_uuid, script_id).await?;
    ensure_assets_linked_to_script(
        pool,
        uid,
        scope_row.project_numeric_id,
        scope_row.script_id,
        &uniq,
    )
    .await?;
    Ok((
        uid,
        pool,
        scope_row.project_numeric_id,
        scope_row.script_id,
        uniq,
    ))
}

pub(super) async fn require_owned_normalized_assets_write_user_pool_ref<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_id: Option<i32>,
    project_uuid: Option<Uuid>,
    script_id: i32,
    asset_ids: &[i32],
) -> Result<(Uuid, &'a PgPool, i32), ApiError> {
    let (uid, pool, project_numeric_id, _script_uuid, _uniq) =
        require_owned_normalized_assets_write_scope_ref(
            state,
            headers,
            project_id,
            project_uuid,
            script_id,
            asset_ids,
        )
        .await?;
    Ok((uid, pool, project_numeric_id))
}
