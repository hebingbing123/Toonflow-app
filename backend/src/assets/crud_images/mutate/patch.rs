use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, validate_positive, ApiError};
use crate::http_kit::json_patch::{
    parse_optional_i32_field, parse_optional_text_field, FieldPatch,
};
use crate::state::AppState;

use super::super::super::crud::{
    require_asset_project_write_scope, resolve_owned_asset_id_for_project,
};
use super::super::super::models::*;

pub(in crate::assets) async fn patch_project_asset_image_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_numeric_id, image_id)): Path<(Uuid, i32, Uuid)>,
    headers: HeaderMap,
    Json(body): Json<PatchAssetImageBody>,
) -> Result<Json<AssetImageRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    validate_positive(asset_numeric_id, "numeric ids")?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    require_asset_project_write_scope(&state, uid, project_id).await?;

    let asset_id =
        resolve_owned_asset_id_for_project(pool, uid, project_id, asset_numeric_id).await?;

    let fp_patch = parse_optional_text_field(body.file_path, "file_path")?;
    let st_patch = parse_optional_text_field(body.state, "state")?;
    let si_patch = parse_optional_i32_field(body.sort_index, "sort_index")?;

    if matches!(fp_patch, FieldPatch::Absent)
        && matches!(st_patch, FieldPatch::Absent)
        && matches!(si_patch, FieldPatch::Absent)
    {
        return Err(bad_request_i18n(
            "expected at least one of: file_path, state, sort_index",
            "file_path、state、sort_index 至少需要提供一个",
        ));
    }

    let current = sqlx::query_as::<_, AssetImageRow>(
        r#"
        SELECT id, asset_id, sort_index, file_path, state, numeric_image_id
        FROM app_asset_image
        WHERE id = $1 AND asset_id = $2
        "#,
    )
    .bind(image_id)
    .bind(asset_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let new_file = match &fp_patch {
        FieldPatch::Absent => current.file_path.clone(),
        FieldPatch::Set(v) => v.clone(),
    };

    let new_state = match &st_patch {
        FieldPatch::Absent => current.state.clone(),
        FieldPatch::Set(v) => v.clone(),
    };

    let new_sort = match &si_patch {
        FieldPatch::Absent => current.sort_index,
        FieldPatch::Set(Some(v)) => *v,
        FieldPatch::Set(None) => {
            return Err(bad_request_i18n(
                "sort_index cannot be null; omit to leave unchanged",
                "sort_index 不能为 null；如需保持不变请省略该字段",
            ));
        }
    };

    let row = sqlx::query_as::<_, AssetImageRow>(
        r#"
        UPDATE app_asset_image
        SET file_path = $1,
            state = $2,
            sort_index = $3,
            updated_at = NOW()
        WHERE id = $4 AND asset_id = $5
        RETURNING id, asset_id, sort_index, file_path, state, numeric_image_id
        "#,
    )
    .bind(new_file)
    .bind(new_state)
    .bind(new_sort)
    .bind(image_id)
    .bind(asset_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}
