use axum::http::header;
use axum::{body::Body, http::StatusCode, response::IntoResponse, response::Response};
use tokio::fs;
use uuid::Uuid;

use crate::error::ApiError;
use crate::state::AppState;

use super::storage::{art_style_cover_api_path, art_style_cover_file_path_for_ext};
use super::types::ArtStyleFileUrlRow;

pub(crate) async fn serve_cover_by_numeric_id(
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
        let path = art_style_cover_file_path_for_ext(root, uid, numeric_id, ext);
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
                    .into_response());
            }
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => continue,
            Err(err) => {
                return Err(ApiError::DatabaseError(format!(
                    "art style cover read failed: {err}"
                )));
            }
        }
    }

    Err(ApiError::NotFound)
}
