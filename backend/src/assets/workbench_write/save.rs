use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use sqlx::types::Json as SqlxJson;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, validate_enum, validate_positive, ApiError};
use crate::state::AppState;

use super::super::crud::require_asset_project_write_scope;
use super::super::models::*;
use super::super::utils::{
    merge_workbench_asset_metadata, normalize_optional_trimmed_text,
    normalize_upload_clip_data_uri, ADV_LOCK_ASSET_IMAGE_NUMERIC,
};

pub(crate) async fn post_project_workbench_save_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchSaveAssetsBody>,
) -> Result<Json<WorkbenchAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    validate_positive(body.id, "id")?;
    let asset_type = body.asset_type.trim().to_lowercase();
    validate_enum(&asset_type, &["role", "scene", "tool"], "type")?;
    if body.image_id.is_some_and(|id| id <= 0) {
        return Err(bad_request_i18n(
            "imageId must be positive when set",
            "imageId 设置时必须为正数",
        ));
    }

    let pool = state.require_pool()?;

    require_asset_project_write_scope(&state, uid, project_id).await?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let current: WorkbenchOwnedAssetMetaRow = sqlx::query_as(
        r#"
        SELECT a.id, a.metadata
        FROM app_asset a
        WHERE a.project_id = $1
          AND a.numeric_id = $2
        "#,
    )
    .bind(project_id)
    .bind(body.id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let mut image_patch = body.image_id;
    if let Some(raw_base64) = body
        .base64
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
    {
        let file_path = normalize_upload_clip_data_uri(raw_base64)?;
        sqlx::query("SELECT pg_advisory_xact_lock($1)")
            .bind(ADV_LOCK_ASSET_IMAGE_NUMERIC)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let next_image_numeric_id: i32 = sqlx::query_scalar(
            r#"SELECT COALESCE(MAX(numeric_image_id), 0) + 1 FROM app_asset_image"#,
        )
        .fetch_one(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let next_sort: i32 = sqlx::query_scalar(
            r#"
            SELECT COALESCE(MAX(sort_index), -1) + 1
            FROM app_asset_image
            WHERE asset_id = $1
            "#,
        )
        .bind(current.id)
        .fetch_one(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        sqlx::query(
            r#"
            INSERT INTO app_asset_image (asset_id, sort_index, file_path, state, numeric_image_id)
            VALUES ($1, $2, $3, '已完成', $4)
            "#,
        )
        .bind(current.id)
        .bind(next_sort)
        .bind(file_path)
        .bind(next_image_numeric_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        image_patch = Some(next_image_numeric_id);
    }

    let metadata = merge_workbench_asset_metadata(
        current.metadata.0,
        Some(normalize_optional_trimmed_text(body.prompt)),
        None,
        Some(image_patch),
    );

    sqlx::query(
        r#"
        UPDATE app_asset
        SET metadata = $1,
            updated_at = NOW()
        WHERE project_id = $2
          AND numeric_id = $3
        "#,
    )
    .bind(SqlxJson(metadata))
    .bind(project_id)
    .bind(body.id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(WorkbenchAssetMutationResponse {
        message: "保存资产图片成功",
    }))
}
