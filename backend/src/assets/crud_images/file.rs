//! 资产图片二进制文件（本地或重定向 URL）。

use axum::{
    body::Body,
    extract::{Path, State},
    http::{header, HeaderMap, StatusCode},
    response::{IntoResponse, Redirect, Response},
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::crud::resolve_owned_asset_id_for_project;
use super::super::models::AssetImageFileSource;

pub(in crate::assets) async fn get_project_asset_image_file_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_numeric_id, image_id)): Path<(Uuid, i32, Uuid)>,
    headers: HeaderMap,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if asset_numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric ids must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let asset_id =
        resolve_owned_asset_id_for_project(pool, uid, project_id, asset_numeric_id).await?;

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
