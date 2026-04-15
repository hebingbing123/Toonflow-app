use axum::{
    extract::{Json, State},
    http::{header, HeaderMap, HeaderValue, StatusCode},
    response::{IntoResponse, Response},
};
use base64::Engine;
use std::borrow::Cow;
use std::io::{Cursor, Write};
use zip::write::FileOptions;

use super::common::{ensure_owned_storyboards, require_pool, require_positive_project_script_ids};
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
    if let Some((ext, bytes)) = decode_data_uri_image(file_path)? {
        return Ok(StoryboardExportFile {
            filename: format!("storyboard-{numeric_id}.{ext}"),
            bytes,
        });
    }

    if file_path.starts_with("http://") || file_path.starts_with("https://") {
        let resp = state.http_client.get(file_path).send().await.map_err(|e| {
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
        let ext = infer_export_extension(file_path, content_type.as_deref());
        return Ok(StoryboardExportFile {
            filename: format!("storyboard-{numeric_id}.{ext}"),
            bytes: bytes.to_vec(),
        });
    }

    let path = std::path::Path::new(file_path);
    if path.is_absolute() {
        let bytes = tokio::fs::read(path).await.map_err(|e| {
            ApiError::BadRequest(format!("failed to read storyboard {numeric_id} file: {e}"))
        })?;
        let ext = path
            .extension()
            .and_then(|s| s.to_str())
            .filter(|s| !s.is_empty())
            .unwrap_or("png");
        return Ok(StoryboardExportFile {
            filename: format!("storyboard-{numeric_id}.{ext}"),
            bytes,
        });
    }

    if let Some(rest) = file_path.strip_prefix("/storyboard-local/") {
        let base = state.local_asset_image_dir.as_ref().ok_or_else(|| {
            ApiError::BadRequest(format!(
                "storyboard {numeric_id} uses local storage but no local image directory is configured"
            ))
        })?;
        let local_path = base.join(owner_user_id.to_string()).join(rest);
        let bytes = tokio::fs::read(&local_path).await.map_err(|e| {
            ApiError::BadRequest(format!(
                "failed to read storyboard {numeric_id} local file: {e}"
            ))
        })?;
        let ext = local_path
            .extension()
            .and_then(|s| s.to_str())
            .filter(|s| !s.is_empty())
            .unwrap_or("png");
        return Ok(StoryboardExportFile {
            filename: format!("storyboard-{numeric_id}.{ext}"),
            bytes,
        });
    }

    Err(ApiError::BadRequest(format!(
        "storyboard {numeric_id} file_path is not exportable: expected http(s), data URI, or absolute file path"
    )))
}

fn decode_data_uri_image(input: &str) -> Result<Option<(&'static str, Vec<u8>)>, ApiError> {
    let Some(rest) = input.strip_prefix("data:") else {
        return Ok(None);
    };
    let Some((meta, payload)) = rest.split_once(',') else {
        return Err(ApiError::BadRequest(
            "invalid data URI for storyboard export".into(),
        ));
    };
    if !meta.ends_with(";base64") {
        return Err(ApiError::BadRequest(
            "storyboard export only supports base64 data URIs".into(),
        ));
    }
    let mime = meta.trim_end_matches(";base64");
    let ext = mime_to_extension(mime).ok_or_else(|| {
        ApiError::BadRequest(format!("unsupported storyboard export mime type: {mime}"))
    })?;
    let bytes = base64::engine::general_purpose::STANDARD
        .decode(payload)
        .map_err(|_| {
            ApiError::BadRequest("invalid base64 data URI for storyboard export".into())
        })?;
    Ok(Some((ext, bytes)))
}

fn infer_export_extension(file_path: &str, content_type: Option<&str>) -> Cow<'static, str> {
    if let Some(ext) = std::path::Path::new(file_path)
        .extension()
        .and_then(|s| s.to_str())
        .filter(|s| !s.is_empty())
    {
        return Cow::Owned(ext.to_ascii_lowercase());
    }

    if let Some(content_type) = content_type {
        if let Some(ext) = mime_to_extension(content_type) {
            return Cow::Borrowed(ext);
        }
    }

    Cow::Borrowed("png")
}

fn mime_to_extension(mime: &str) -> Option<&'static str> {
    let bare = mime.split(';').next()?.trim().to_ascii_lowercase();
    match bare.as_str() {
        "image/png" => Some("png"),
        "image/jpeg" => Some("jpg"),
        "image/webp" => Some("webp"),
        "image/gif" => Some("gif"),
        "image/svg+xml" => Some("svg"),
        _ => None,
    }
}
