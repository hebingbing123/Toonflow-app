use axum::{
    body::Body,
    extract::{Query, State},
    http::{header, HeaderMap, StatusCode},
    response::{IntoResponse, Redirect, Response},
};
use serde::Deserialize;
use uuid::Uuid;

use crate::error::ApiError;
use crate::scope::http::require_storyboard_read_scope_ref;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct LocalFrameQuery {
    project_id: Option<i32>,
    project_uuid: Option<Uuid>,
    script_id: i32,
    storyboard_id: i32,
}

/// Serves storyboard `file_path` when stored under `/storyboard-local/` or redirects http(s).
pub(in crate::production) async fn get_storyboard_local_frame(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<LocalFrameQuery>,
) -> Result<Response, ApiError> {
    let (pool, sb_uuid) = require_storyboard_read_scope_ref(
        &state,
        &headers,
        query.project_id,
        query.project_uuid,
        query.script_id,
        query.storyboard_id,
    )
    .await?;

    let file_path: Option<String> =
        sqlx::query_scalar(r#"SELECT file_path FROM app_storyboard WHERE id = $1"#)
            .bind(sb_uuid)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(path) = file_path.filter(|p| !p.trim().is_empty()) else {
        return Err(ApiError::NotFound);
    };

    if path.starts_with("http://") || path.starts_with("https://") {
        return Ok(Redirect::temporary(path.as_str()).into_response());
    }

    if path.starts_with("data:image/") {
        return Err(ApiError::BadRequest(
            "data URI frames must be loaded client-side".into(),
        ));
    }

    let Some(rest) = path.strip_prefix("/storyboard-local/") else {
        return Err(ApiError::NotFound);
    };

    let uid = crate::auth::require_user_uuid(&state, &headers)?;
    let Some(ref root) = state.local_asset_image_dir else {
        return Err(ApiError::DatabaseError(
            "OPENFLOW_LOCAL_ASSET_IMAGE_DIR is not set".into(),
        ));
    };

    let disk_path = root.join(uid.to_string()).join(rest);
    let bytes = tokio::fs::read(&disk_path)
        .await
        .map_err(|_| ApiError::NotFound)?;

    Ok((
        StatusCode::OK,
        [
            (header::CONTENT_TYPE, "image/png"),
            (header::CACHE_CONTROL, "private, max-age=120"),
        ],
        Body::from(bytes),
    )
        .into_response())
}
