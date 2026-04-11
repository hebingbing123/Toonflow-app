//! `POST …/assets` — create asset.

use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::models::*;
use super::super::ADV_LOCK_ASSET_LEGACY;
use super::resolve::{ensure_owned_project_pk, resolve_owned_project_pk_by_legacy};

async fn create_project_asset_inner(
    pool: &sqlx::PgPool,
    project_uuid: Uuid,
    body: CreateAssetBody,
) -> Result<(StatusCode, Json<AssetRow>), ApiError> {
    let name = body.name.trim().to_string();
    if name.is_empty() {
        return Err(ApiError::BadRequest("name must not be empty".into()));
    }

    let t = body.asset_type.trim().to_lowercase();
    if t != "role" && t != "tool" && t != "scene" {
        return Err(ApiError::BadRequest(
            "type must be role, tool, or scene".into(),
        ));
    }

    let desc = body
        .description
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty());

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let exists: bool = sqlx::query_scalar(
        r#"SELECT EXISTS (SELECT 1 FROM app_asset WHERE project_id = $1 AND name = $2)"#,
    )
    .bind(project_uuid)
    .bind(&name)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if exists {
        tx.rollback().await.ok();
        return Err(ApiError::Conflict(
            "an asset with this name already exists in the project".into(),
        ));
    }

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ASSET_LEGACY)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_legacy: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(legacy_id), 0) + 1 FROM app_asset"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();

    let row = sqlx::query_as::<_, AssetRow>(
        r#"
        INSERT INTO app_asset (
          project_id, legacy_id, name, asset_type, description, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, '{}'::jsonb)
        RETURNING id, legacy_id, name, asset_type, description, create_time_ms
        "#,
    )
    .bind(project_uuid)
    .bind(next_legacy)
    .bind(&name)
    .bind(&t)
    .bind(desc)
    .bind(now_ms)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((StatusCode::CREATED, Json(row)))
}

pub(crate) async fn create_project_asset_for_project(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<CreateAssetBody>,
) -> Result<(StatusCode, Json<AssetRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;
    create_project_asset_inner(pool, project_id, body).await
}

pub(crate) async fn create_project_asset(
    State(state): State<AppState>,
    Path(project_legacy_id): Path<i32>,
    headers: HeaderMap,
    Json(body): Json<CreateAssetBody>,
) -> Result<(StatusCode, Json<AssetRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let project_uuid = resolve_owned_project_pk_by_legacy(pool, uid, project_legacy_id).await?;
    create_project_asset_inner(pool, project_uuid, body).await
}
