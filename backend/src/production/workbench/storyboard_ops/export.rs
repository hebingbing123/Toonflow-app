use axum::{
    extract::{Json, State},
    http::{header, HeaderMap, HeaderValue, StatusCode},
    response::{IntoResponse, Response},
};
use std::io::{Cursor, Write};
use zip::write::FileOptions;

use super::common::{ensure_owned_storyboards, require_pool, require_positive_project_script_ids};
use super::export_source::{
    infer_export_extension, parse_storyboard_export_source, StoryboardExportSource,
};
use super::types::{ExportImageBody, ExportImageSourceRow};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::scope;
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
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_project_script_ids(body.project_id, body.script_id)?;
    if body.shot_id.is_empty() {
        return Err(ApiError::BadRequest(
            "shotId must be a non-empty array".into(),
        ));
    }

    let mut uniq = Vec::with_capacity(body.shot_id.len());
    for s in body.shot_id {
        let t = s.id.trim();
        let parsed: i32 = t
            .parse()
            .map_err(|_| ApiError::BadRequest("shotId.id must be a positive integer".into()))?;
        if parsed <= 0 {
            return Err(ApiError::BadRequest(
                "shotId.id must be a positive integer".into(),
            ));
        }
        uniq.push(parsed);
    }

    let pool = require_pool(&state)?;
    let scope_row = scope::owned_script_scope(pool, uid, body.project_id, body.script_id)
        .await
        .map_err(|e| e.into_api_error())?;

    uniq.sort_unstable();
    uniq.dedup();
    ensure_owned_storyboards(pool, scope_row.script_id, &uniq).await?;

    let rows = sqlx::query_as::<_, ExportImageSourceRow>(
        r#"
        SELECT sb.numeric_id, sb.file_path
        FROM app_storyboard sb
        WHERE sb.script_id = $1
          AND sb.numeric_id = ANY($2::int4[])
        ORDER BY array_position($2::int4[], sb.numeric_id)
        "#,
    )
    .bind(scope_row.script_id)
    .bind(&uniq)
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

async fn build_storyboard_export_zip(
    state: &AppState,
    owner_user_id: uuid::Uuid,
    rows: Vec<ExportImageSourceRow>,
) -> Result<Vec<u8>, ApiError> {
    let mut archive = zip::ZipWriter::new(Cursor::new(Vec::new()));
    let options = FileOptions::default().compression_method(zip::CompressionMethod::Deflated);

    for row in rows {
        let file_path = row.file_path.as_deref().ok_or_else(|| {
            ApiError::BadRequest(format!(
                "storyboard {} has no generated image to export",
                row.numeric_id
            ))
        })?;

        let exported =
            fetch_storyboard_export_bytes(state, owner_user_id, row.numeric_id, file_path).await?;
        archive
            .start_file(exported.filename, options)
            .map_err(|_| ApiError::Internal)?;
        archive
            .write_all(&exported.bytes)
            .map_err(|_| ApiError::Internal)?;
    }

    archive
        .finish()
        .map(|cursor| cursor.into_inner())
        .map_err(|_| ApiError::Internal)
}

struct StoryboardExportFile {
    filename: String,
    bytes: Vec<u8>,
}

async fn fetch_storyboard_export_bytes(
    state: &AppState,
    owner_user_id: uuid::Uuid,
    numeric_id: i32,
    file_path: &str,
) -> Result<StoryboardExportFile, ApiError> {
    match parse_storyboard_export_source(file_path, numeric_id)? {
        StoryboardExportSource::DataUri { extension, bytes } => Ok(StoryboardExportFile {
            filename: format!("storyboard-{numeric_id}.{extension}"),
            bytes,
        }),
        StoryboardExportSource::RemoteUrl { url } => {
            let resp = state.http_client.get(&url).send().await.map_err(|e| {
                ApiError::BadRequest(format!(
                    "failed to fetch storyboard {numeric_id} image: {e}"
                ))
            })?;
            if !resp.status().is_success() {
                return Err(ApiError::BadRequest(format!(
                    "failed to fetch storyboard {numeric_id} image: upstream status {}",
                    resp.status()
                )));
            }
            let content_type = resp
                .headers()
                .get(header::CONTENT_TYPE)
                .and_then(|v| v.to_str().ok())
                .map(str::to_string);
            let bytes = resp.bytes().await.map_err(|e| {
                ApiError::BadRequest(format!("failed to read storyboard {numeric_id} image: {e}"))
            })?;
            let extension = infer_export_extension(&url, content_type.as_deref());
            Ok(StoryboardExportFile {
                filename: format!("storyboard-{numeric_id}.{extension}"),
                bytes: bytes.to_vec(),
            })
        }
        StoryboardExportSource::AbsolutePath { path } => {
            let bytes = tokio::fs::read(&path).await.map_err(|e| {
                ApiError::BadRequest(format!("failed to read storyboard {numeric_id} file: {e}"))
            })?;
            let extension = path
                .extension()
                .and_then(|s| s.to_str())
                .filter(|s| !s.is_empty())
                .unwrap_or("png");
            Ok(StoryboardExportFile {
                filename: format!("storyboard-{numeric_id}.{extension}"),
                bytes,
            })
        }
        StoryboardExportSource::LocalStorage { relative_path } => {
            let base = state.local_asset_image_dir.as_ref().ok_or_else(|| {
                ApiError::BadRequest(format!(
                    "storyboard {numeric_id} uses local storage but no local image directory is configured"
                ))
            })?;
            let local_path = base.join(owner_user_id.to_string()).join(relative_path);
            let bytes = tokio::fs::read(&local_path).await.map_err(|e| {
                ApiError::BadRequest(format!(
                    "failed to read storyboard {numeric_id} local file: {e}"
                ))
            })?;
            let extension = local_path
                .extension()
                .and_then(|s| s.to_str())
                .filter(|s| !s.is_empty())
                .unwrap_or("png");
            Ok(StoryboardExportFile {
                filename: format!("storyboard-{numeric_id}.{extension}"),
                bytes,
            })
        }
    }
}
