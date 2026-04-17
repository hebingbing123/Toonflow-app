use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::crud::ensure_owned_project_pk;
use super::super::models::*;

pub(crate) async fn post_project_workbench_del_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchDeleteAssetsBody>,
) -> Result<Json<WorkbenchAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.id <= 0 {
        return Err(ApiError::BadRequest("id must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    sqlx::query(
        r#"
        DELETE FROM app_asset a
        USING app_project p
        WHERE a.project_id = p.id
          AND p.owner_user_id = $1
          AND p.id = $2
          AND a.numeric_id = $3
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(WorkbenchAssetMutationResponse {
        message: "删除资产成功",
    }))
}

pub(crate) async fn post_project_workbench_batch_delete_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchBatchDeleteAssetsBody>,
) -> Result<Json<WorkbenchAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.id.is_empty() {
        return Err(ApiError::BadRequest("id must not be empty".into()));
    }
    if body.id.iter().any(|id| *id <= 0) {
        return Err(ApiError::BadRequest("id entries must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    sqlx::query(
        r#"
        DELETE FROM app_asset a
        USING app_project p
        WHERE a.project_id = p.id
          AND p.owner_user_id = $1
          AND p.id = $2
          AND a.numeric_id = ANY($3)
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(&body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(WorkbenchAssetMutationResponse {
        message: "删除资产成功",
    }))
}

pub(crate) async fn post_project_workbench_del_image(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchDelImageBody>,
) -> Result<Json<WorkbenchAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.id <= 0 {
        return Err(ApiError::BadRequest("id must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;

    sqlx::query(
        r#"
        UPDATE app_asset a
        SET metadata = a.metadata - 'imageId',
            updated_at = NOW()
        FROM app_project p
        WHERE a.project_id = p.id
          AND p.owner_user_id = $1
          AND p.id = $2
          AND COALESCE(a.metadata->>'imageId', '') ~ '^[0-9]+$'
          AND (a.metadata->>'imageId')::integer = $3
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_asset_image ai
        USING app_asset a, app_project p
        WHERE ai.asset_id = a.id
          AND a.project_id = p.id
          AND p.owner_user_id = $1
          AND p.id = $2
          AND ai.numeric_image_id = $3
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(WorkbenchAssetMutationResponse {
        message: "资产图片删除成功",
    }))
}
