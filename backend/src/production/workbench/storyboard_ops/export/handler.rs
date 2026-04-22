//! `POST /api/v1/production/export-image`：打包分镜图为 zip。

use axum::{
    extract::{Json, State},
    http::{header, HeaderMap, HeaderValue, StatusCode},
    response::{IntoResponse, Response},
};

use super::super::common::require_owned_normalized_storyboards_scope;
use super::super::types::{ExportImageBody, ExportImageSourceRow};
use super::shot_ids::normalize_export_shot_ids;
use super::zip_export::build_storyboard_export_zip;
use crate::error::ApiError;
use crate::state::AppState;

#[utoipa::path(
    post,
    path = "/api/v1/production/export-image",
    operation_id = "postProductionExportImageV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_export_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ExportImageBody>,
) -> Result<Response, ApiError> {
    let normalized_ids = normalize_export_shot_ids(&body.shot_id)?;

    let (uid, pool, script_id, _confirmed_ids) = require_owned_normalized_storyboards_scope(
        &state,
        &headers,
        body.project_id,
        body.script_id,
        &normalized_ids,
    )
    .await?;

    let rows = sqlx::query_as::<_, ExportImageSourceRow>(
        r#"
        SELECT
            sb.numeric_id,
            sb.file_path,
            sb.prompt,
            sb.duration,
            sb.state,
            sb.track_id,
            sb.sb_index
        FROM app_storyboard sb
        WHERE sb.script_id = $1
          AND sb.numeric_id = ANY($2::int4[])
        ORDER BY array_position($2::int4[], sb.numeric_id)
        "#,
    )
    .bind(script_id)
    .bind(&normalized_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let zip_bytes = build_storyboard_export_zip(&state, uid, rows).await?;
    let filename = format!(
        "toonflow-storyboards-{}.zip",
        chrono::Utc::now().format("%Y%m%dT%H%M%SZ")
    );

    let mut disposition = HeaderValue::from_str(&format!("attachment; filename=\"{filename}\""))
        .map_err(|_| ApiError::Internal)?;
    disposition.set_sensitive(true);

    Ok((
        StatusCode::OK,
        [
            (
                header::CONTENT_TYPE,
                HeaderValue::from_static("application/zip"),
            ),
            (
                header::CACHE_CONTROL,
                HeaderValue::from_static("private, max-age=0"),
            ),
            (header::CONTENT_DISPOSITION, disposition),
        ],
        axum::body::Body::from(zip_bytes),
    )
        .into_response())
}
