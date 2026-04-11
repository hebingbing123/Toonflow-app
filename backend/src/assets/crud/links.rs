//! 脚本 ↔ 资产关联处理器。
//!
//! 处理脚本与资产之间的关联和解除关联操作。

use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;
use sqlx::PgPool;
use uuid::Uuid;

async fn resolve_script_and_asset_in_project(
    pool: &PgPool,
    uid: Uuid,
    project_legacy_id: i32,
    script_legacy_id: i32,
    asset_legacy_id: i32,
) -> Result<(Uuid, Uuid), ApiError> {
    let row: Option<(Uuid, Uuid)> = sqlx::query_as(
        r#"
        SELECT s.id, a.id
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        INNER JOIN app_asset a ON a.project_id = p.id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND s.legacy_id = $3
          AND a.legacy_id = $4
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .bind(script_legacy_id)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    row.ok_or(ApiError::NotFound)
}

pub(crate) async fn link_script_to_asset(
    State(state): State<AppState>,
    Path((project_legacy_id, script_legacy_id, asset_legacy_id)): Path<(i32, i32, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || script_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let (script_id, asset_id) = resolve_script_and_asset_in_project(
        pool,
        uid,
        project_legacy_id,
        script_legacy_id,
        asset_legacy_id,
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

pub(crate) async fn unlink_script_from_asset(
    State(state): State<AppState>,
    Path((project_legacy_id, script_legacy_id, asset_legacy_id)): Path<(i32, i32, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if project_legacy_id <= 0 || script_legacy_id <= 0 || asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let (script_id, asset_id) = resolve_script_and_asset_in_project(
        pool,
        uid,
        project_legacy_id,
        script_legacy_id,
        asset_legacy_id,
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
