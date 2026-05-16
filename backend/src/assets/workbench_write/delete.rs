use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, validate_positive, ApiError};
use crate::state::AppState;

use super::super::crud::require_asset_project_write_scope;
use super::super::models::*;

pub(crate) async fn post_project_workbench_del_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchDeleteAssetsBody>,
) -> Result<Json<WorkbenchAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    validate_positive(body.id, "id")?;

    let pool = state.require_pool()?;

    require_asset_project_write_scope(&state, uid, project_id).await?;

    sqlx::query(
        r#"
        DELETE FROM app_asset
        WHERE project_id = $1
          AND numeric_id = $2
        "#,
    )
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
        return Err(bad_request_i18n("id must not be empty", "id 不能为空"));
    }
    if body.id.iter().any(|id| *id <= 0) {
        return Err(bad_request_i18n(
            "id entries must be positive",
            "id 列表中的每一项都必须为正数",
        ));
    }

    let pool = state.require_pool()?;

    require_asset_project_write_scope(&state, uid, project_id).await?;

    sqlx::query(
        r#"
        DELETE FROM app_asset
        WHERE project_id = $1
          AND numeric_id = ANY($2)
        "#,
    )
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
    validate_positive(body.id, "id")?;

    let pool = state.require_pool()?;

    require_asset_project_write_scope(&state, uid, project_id).await?;

    sqlx::query(
        r#"
        UPDATE app_asset a
        SET metadata = a.metadata - 'imageId',
            updated_at = NOW()
        WHERE a.project_id = $1
          AND COALESCE(a.metadata->>'imageId', '') ~ '^[0-9]+$'
          AND (a.metadata->>'imageId')::integer = $2
        "#,
    )
    .bind(project_id)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_asset_image ai
        USING app_asset a
        WHERE ai.asset_id = a.id
          AND a.project_id = $1
          AND ai.numeric_image_id = $2
        "#,
    )
    .bind(project_id)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(WorkbenchAssetMutationResponse {
        message: "资产图片删除成功",
    }))
}
