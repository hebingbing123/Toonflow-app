//! 脚本 ↔ 资产关联处理器。
//!
//! 处理脚本与资产之间的关联和解除关联操作。

use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::scope;
use crate::state::AppState;
use sqlx::PgPool;

async fn resolve_script_and_asset_for_project(
    pool: &PgPool,
    uid: Uuid,
    project_id: Uuid,
    script_numeric_id: i32,
    asset_numeric_id: i32,
) -> Result<(Uuid, Uuid), ApiError> {
    if script_numeric_id <= 0 || asset_numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric ids must be positive".into()));
    }
    let oip = scope::owned_script_in_project(pool, uid, project_id, script_numeric_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let asset_id: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT id FROM app_asset
        WHERE project_id = $1 AND numeric_id = $2
        "#,
    )
    .bind(oip.project_id)
    .bind(asset_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let asset_id = asset_id.ok_or(ApiError::NotFound)?;
    Ok((oip.script_id, asset_id))
}

pub(crate) async fn link_script_to_asset_for_project(
    State(state): State<AppState>,
    Path((project_id, script_numeric_id, asset_numeric_id)): Path<(Uuid, i32, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let (script_id, asset_id) = resolve_script_and_asset_for_project(
        pool,
        uid,
        project_id,
        script_numeric_id,
        asset_numeric_id,
    )
    .await?;

    sqlx::query(
        r#"
        INSERT INTO app_script_asset (script_id, asset_id)
        VALUES ($1, $2)
        ON CONFLICT (script_id, asset_id) DO NOTHING
        "#,
    )
    .bind(script_id)
    .bind(asset_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(StatusCode::NO_CONTENT)
}

pub(crate) async fn unlink_script_from_asset_for_project(
    State(state): State<AppState>,
    Path((project_id, script_numeric_id, asset_numeric_id)): Path<(Uuid, i32, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let (script_id, asset_id) = resolve_script_and_asset_for_project(
        pool,
        uid,
        project_id,
        script_numeric_id,
        asset_numeric_id,
    )
    .await?;

    let res = sqlx::query(r#"DELETE FROM app_script_asset WHERE script_id = $1 AND asset_id = $2"#)
        .bind(script_id)
        .bind(asset_id)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}
