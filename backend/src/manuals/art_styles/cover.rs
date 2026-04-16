use std::path::{Path as FsPath, PathBuf};

use axum::http::header;
use axum::{body::Body, http::StatusCode, response::IntoResponse, response::Response};
use base64::Engine as _;
use sqlx::FromRow;
use tokio::fs;
use uuid::Uuid;

use crate::error::ApiError;
use crate::state::AppState;

use super::types::{MAX_ART_STYLE_COVER_BYTES, MAX_ART_STYLE_COVER_INPUT_CHARS};

#[derive(Debug, Clone)]
pub(crate) struct LocalArtStyleCover {
    pub(crate) bytes: Vec<u8>,
    pub(crate) ext: &'static str,
}

#[derive(Debug, FromRow)]
pub(super) struct ArtStyleFileUrlRow {
    pub(super) file_url: Option<String>,
}

fn is_http_url(s: &str) -> bool {
    s.starts_with("http://") || s.starts_with("https://")
}

pub(crate) fn art_style_cover_api_path(numeric_id: i32) -> String {
    format!("/api/v1/art-styles/numeric/{numeric_id}/cover")
}

pub(crate) fn parse_uploaded_cover(raw: &str) -> Result<Option<LocalArtStyleCover>, ApiError> {
    let trimmed = raw.trim();
    if trimmed.is_empty() || is_http_url(trimmed) || trimmed.starts_with('/') {
        return Ok(None);
    }
    if trimmed.len() > MAX_ART_STYLE_COVER_INPUT_CHARS {
        return Err(ApiError::BadRequest(format!(
            "art style file_url exceeds max length ({MAX_ART_STYLE_COVER_INPUT_CHARS} chars)"
        )));
    }

    let (mime, b64) = match trimmed.strip_prefix("data:") {
        Some(rest) => {
            let (meta, b64) = rest.split_once(";base64,").ok_or_else(|| {
                ApiError::BadRequest("art style file_url data URI must be base64".into())
            })?;
            let mime = match meta.trim().to_ascii_lowercase().as_str() {
                "image/png" => "image/png",
                "image/jpeg" | "image/jpg" => "image/jpeg",
                "image/webp" => "image/webp",
                _ => return Err(ApiError::BadRequest(
                    "art style file_url must be png/jpeg/webp data URI, http(s) URL, or API path"
                        .into(),
                )),
            };
            (mime, b64.trim())
        }
        None => ("image/jpeg", trimmed),
    };

    let bytes = base64::engine::general_purpose::STANDARD
        .decode(b64.as_bytes())
        .map_err(|_| ApiError::BadRequest("art style file_url is not valid base64".into()))?;
    if bytes.is_empty() {
        return Err(ApiError::BadRequest(
            "art style file_url decoded to empty image".into(),
        ));
    }
    if bytes.len() > MAX_ART_STYLE_COVER_BYTES {
        return Err(ApiError::BadRequest(format!(
            "art style cover exceeds max decoded size ({MAX_ART_STYLE_COVER_BYTES} bytes)"
        )));
    }

    let ext = match mime {
        "image/png" => "png",
        "image/webp" => "webp",
        _ => "jpg",
    };
    Ok(Some(LocalArtStyleCover { bytes, ext }))
}

fn art_style_cover_file_path(
    root: &FsPath,
    owner_user_id: Uuid,
    numeric_id: i32,
    ext: &str,
) -> PathBuf {
    root.join(owner_user_id.to_string())
        .join(format!("{numeric_id}.{ext}"))
}

fn existing_art_style_cover_paths(
    root: &FsPath,
    owner_user_id: Uuid,
    numeric_id: i32,
) -> [PathBuf; 3] {
    [
        art_style_cover_file_path(root, owner_user_id, numeric_id, "png"),
        art_style_cover_file_path(root, owner_user_id, numeric_id, "jpg"),
        art_style_cover_file_path(root, owner_user_id, numeric_id, "webp"),
    ]
}

pub(super) async fn delete_local_art_style_cover_files(
    root: &FsPath,
    owner_user_id: Uuid,
    numeric_id: i32,
) {
    for path in existing_art_style_cover_paths(root, owner_user_id, numeric_id) {
        let _ = fs::remove_file(path).await;
    }
}

pub(super) async fn persist_local_art_style_cover(
    root: &FsPath,
    owner_user_id: Uuid,
    numeric_id: i32,
    cover: &LocalArtStyleCover,
) -> Result<(), ApiError> {
    let dir = root.join(owner_user_id.to_string());
    fs::create_dir_all(&dir)
        .await
        .map_err(|e| ApiError::BadRequest(format!("art style cover mkdir failed: {e}")))?;
    delete_local_art_style_cover_files(root, owner_user_id, numeric_id).await;
    let path = art_style_cover_file_path(root, owner_user_id, numeric_id, cover.ext);
    fs::write(&path, &cover.bytes)
        .await
        .map_err(|e| ApiError::BadRequest(format!("art style cover write failed: {e}")))?;
    Ok(())
}

pub(super) async fn serve_cover_by_numeric_id(
    state: &AppState,
    uid: Uuid,
    numeric_id: i32,
) -> Result<Response, ApiError> {
    let pool = state.require_pool()?;
    let row = sqlx::query_as::<_, ArtStyleFileUrlRow>(
        r#"
        SELECT file_url
        FROM app_art_style
        WHERE owner_user_id = $1 AND numeric_id = $2
        "#,
    )
    .bind(uid)
    .bind(numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    if row.file_url.as_deref() != Some(art_style_cover_api_path(numeric_id).as_str()) {
        return Err(ApiError::NotFound);
    }

    let Some(root) = state.local_art_style_cover_dir.as_deref() else {
        return Err(ApiError::DatabaseError(
            "TOONFLOW_LOCAL_ART_STYLE_COVER_DIR is not set; cannot serve local art style covers"
                .into(),
        ));
    };

    for (ext, mime) in [
        ("png", "image/png"),
        ("jpg", "image/jpeg"),
        ("webp", "image/webp"),
    ] {
        let path = art_style_cover_file_path(root, uid, numeric_id, ext);
        match fs::read(&path).await {
            Ok(bytes) => {
                return Ok((
                    StatusCode::OK,
                    [
                        (header::CONTENT_TYPE, mime),
                        (header::CACHE_CONTROL, "private, max-age=300"),
                    ],
                    Body::from(bytes),
                )
                    .into_response())
            }
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => continue,
            Err(err) => {
                return Err(ApiError::DatabaseError(format!(
                    "art style cover read failed: {err}"
                )))
            }
        }
    }

    Err(ApiError::NotFound)
}
