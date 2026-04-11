//! 资产图片 REST CRUD 操作。
//!
//! 处理 `app_asset_image` 行的列表、获取、文件、创建、更新和删除操作。
//! 端点路径：`/api/v1/projects/{project_id}/assets/{asset_legacy_id}/images`

use axum::{
    body::Body,
    extract::{Path, State},
    http::{header, HeaderMap, StatusCode},
    response::{IntoResponse, Redirect, Response},
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::http_kit::json_patch::{
    parse_optional_i32_field, parse_optional_text_field, FieldPatch,
};
use crate::state::AppState;

use super::crud::{
    resolve_owned_asset_id_and_metadata_for_project, resolve_owned_asset_id_for_project,
};
use super::metadata_cover_legacy_image_id;
use super::models::*;

pub(super) async fn list_project_asset_images_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_legacy_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<Json<ListAssetImagesResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let (asset_id, metadata) =
        resolve_owned_asset_id_and_metadata_for_project(pool, uid, project_id, asset_legacy_id)
            .await?;
    let cover_legacy_image_id = metadata_cover_legacy_image_id(&metadata);

    let rows = sqlx::query_as::<_, AssetImageRow>(
        r#"
        SELECT id, asset_id, sort_index, file_path, state, legacy_image_id
        FROM app_asset_image
        WHERE asset_id = $1
        ORDER BY sort_index ASC, created_at ASC
        "#,
    )
    .bind(asset_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let items: Vec<AssetImageListItem> = rows
        .into_iter()
        .map(|row| {
            let selected = cover_legacy_image_id.is_some_and(|c| row.legacy_image_id == Some(c));
            AssetImageListItem { row, selected }
        })
        .collect();

    Ok(Json(ListAssetImagesResponse {
        cover_legacy_image_id,
        items,
    }))
}

pub(super) async fn get_project_asset_image_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_legacy_id, image_id)): Path<(Uuid, i32, Uuid)>,
    headers: HeaderMap,
) -> Result<Json<AssetImageRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let asset_id =
        resolve_owned_asset_id_for_project(pool, uid, project_id, asset_legacy_id).await?;

    let row = sqlx::query_as::<_, AssetImageRow>(
        r#"
        SELECT id, asset_id, sort_index, file_path, state, legacy_image_id
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

    Ok(Json(row))
}

pub(super) async fn get_project_asset_image_file_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_legacy_id, image_id)): Path<(Uuid, i32, Uuid)>,
    headers: HeaderMap,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let asset_id =
        resolve_owned_asset_id_for_project(pool, uid, project_id, asset_legacy_id).await?;

    let row = sqlx::query_as::<_, AssetImageFileSource>(
        r#"
        SELECT i.file_path, i.metadata
        FROM app_asset_image i
        WHERE i.id = $1 AND i.asset_id = $2
        "#,
    )
    .bind(image_id)
    .bind(asset_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    if let Some(u) = row.file_path.as_deref() {
        if u.starts_with("http://") || u.starts_with("https://") {
            let _: axum::http::Uri = u.parse().map_err(|_| {
                ApiError::BadRequest("asset image file_path is not a valid URL".into())
            })?;
            return Ok(Redirect::temporary(u).into_response());
        }
    }

    if row.metadata.0.get("storage").and_then(|x| x.as_str()) != Some("local") {
        return Err(ApiError::NotFound);
    }

    let Some(ref root) = state.local_asset_image_dir else {
        return Err(ApiError::DatabaseError(
            "TOONFLOW_LOCAL_ASSET_IMAGE_DIR is not set; cannot serve locally stored asset images"
                .into(),
        ));
    };

    let path = root.join(uid.to_string()).join(format!("{image_id}.png"));
    let bytes = tokio::fs::read(&path)
        .await
        .map_err(|_| ApiError::NotFound)?;

    Ok((
        StatusCode::OK,
        [
            (header::CONTENT_TYPE, "image/png"),
            (header::CACHE_CONTROL, "private, max-age=300"),
        ],
        Body::from(bytes),
    )
        .into_response())
}

pub(super) async fn create_project_asset_image_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_legacy_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
    Json(body): Json<CreateAssetImageBody>,
) -> Result<(StatusCode, Json<AssetImageRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let asset_id =
        resolve_owned_asset_id_for_project(pool, uid, project_id, asset_legacy_id).await?;

    let file_path = body
        .file_path
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string());

    let sort_index = body.sort_index.unwrap_or(0);

    let state_val: Option<String> = match &body.state {
        None => Some("已完成".into()),
        Some(s) if s.trim().is_empty() => None,
        Some(s) => Some(s.trim().to_string()),
    };

    let row = sqlx::query_as::<_, AssetImageRow>(
        r#"
        INSERT INTO app_asset_image (asset_id, sort_index, file_path, state)
        VALUES ($1, $2, $3, $4)
        RETURNING id, asset_id, sort_index, file_path, state, legacy_image_id
        "#,
    )
    .bind(asset_id)
    .bind(sort_index)
    .bind(file_path)
    .bind(state_val)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or_else(|| ApiError::DatabaseError("insert app_asset_image failed".into()))?;

    Ok((StatusCode::CREATED, Json(row)))
}

pub(super) async fn patch_project_asset_image_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_legacy_id, image_id)): Path<(Uuid, i32, Uuid)>,
    headers: HeaderMap,
    Json(body): Json<PatchAssetImageBody>,
) -> Result<Json<AssetImageRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let asset_id =
        resolve_owned_asset_id_for_project(pool, uid, project_id, asset_legacy_id).await?;

    let fp_patch = parse_optional_text_field(body.file_path, "file_path")?;
    let st_patch = parse_optional_text_field(body.state, "state")?;
    let si_patch = parse_optional_i32_field(body.sort_index, "sort_index")?;

    if matches!(fp_patch, FieldPatch::Absent)
        && matches!(st_patch, FieldPatch::Absent)
        && matches!(si_patch, FieldPatch::Absent)
    {
        return Err(ApiError::BadRequest(
            "expected at least one of: file_path, state, sort_index".into(),
        ));
    }

    let current = sqlx::query_as::<_, AssetImageRow>(
        r#"
        SELECT id, asset_id, sort_index, file_path, state, legacy_image_id
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
            return Err(ApiError::BadRequest(
                "sort_index cannot be null; omit to leave unchanged".into(),
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
        RETURNING id, asset_id, sort_index, file_path, state, legacy_image_id
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

pub(super) async fn delete_project_asset_image_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_legacy_id, image_id)): Path<(Uuid, i32, Uuid)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if asset_legacy_id <= 0 {
        return Err(ApiError::BadRequest("legacy ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let asset_id =
        resolve_owned_asset_id_for_project(pool, uid, project_id, asset_legacy_id).await?;

    let res = sqlx::query(
        r#"
        DELETE FROM app_asset_image
        WHERE id = $1 AND asset_id = $2
        "#,
    )
    .bind(image_id)
    .bind(asset_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}
