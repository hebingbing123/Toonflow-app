//! `POST …/assets` — create asset.

use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{validate_enum, validate_non_empty_string, ApiError};
use crate::state::AppState;

use super::super::models::*;
use super::super::ADV_LOCK_ASSET_NUMERIC;
use super::resolve::require_asset_project_write_scope;

async fn create_project_asset_inner(
    pool: &sqlx::PgPool,
    project_uuid: Uuid,
    body: CreateAssetBody,
) -> Result<(StatusCode, Json<AssetRow>), ApiError> {
    let name = body.name.trim().to_string();
    validate_non_empty_string(&name, "name")?;

    let t = body.asset_type.trim().to_lowercase();
    validate_enum(&t, &["role", "tool", "scene"], "type")?;

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
            match crate::error::locale::current_locale() {
                crate::error::ApiLocale::En => {
                    "an asset with this name already exists in the project".into()
                }
                crate::error::ApiLocale::Zh => "项目中已存在同名资产".into(),
            },
        ));
    }

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ASSET_NUMERIC)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_numeric_id: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(numeric_id), 0) + 1 FROM app_asset"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();

    let row = sqlx::query_as::<_, AssetRow>(
        r#"
        INSERT INTO app_asset (
          project_id, numeric_id, name, asset_type, description, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, '{}'::jsonb)
        RETURNING id, numeric_id, name, asset_type, description, create_time_ms, candidate_status
        "#,
    )
    .bind(project_uuid)
    .bind(next_numeric_id)
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

    require_asset_project_write_scope(&state, uid, project_id).await?;
    create_project_asset_inner(pool, project_id, body).await
}
