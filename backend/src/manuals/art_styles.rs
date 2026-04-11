//! 用户范围的 `app_art_style` REST（遗留 `o_artStyle` 列表/获取/创建/更新/删除子集）。

use std::path::{Path as FsPath, PathBuf};

use axum::{
    body::Body,
    extract::{Path, State},
    http::{header, HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use base64::Engine;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::FromRow;
use tokio::fs;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::http_kit::json_patch::{parse_optional_text_field, FieldPatch};
use crate::llm::chat_completion_assistant_text;
use crate::state::AppState;

const ADV_LOCK_ART_STYLE_LEGACY: i64 = 884_422_008;
const MAX_ART_STYLE_LIST: i64 = 500;
const MAX_EXTRACT_IMAGES: usize = 16;
/// Per-image cap for **`data:`** / URL strings (legacy **`extractStylePrompt`** had no limit).
const MAX_IMAGE_ENTRY_BYTES: usize = 20 * 1024 * 1024;
const MAX_ART_STYLE_COVER_INPUT_CHARS: usize = 20 * 1024 * 1024;
const MAX_ART_STYLE_COVER_BYTES: usize = 15 * 1024 * 1024;

/// System prompt aligned with legacy **`src/routes/artStyle/extractStylePrompt.ts`**.
const EXTRACT_STYLE_SYSTEM_PROMPT: &str = r#"请根据以下图片数据，提取出图片的画风提示词，用于生成图片时指定风格，要求简洁且具有艺术性,只需要画风提示词，不需要其他内容："比如：`(画风：2D动漫风格,2d animation style)`,`(画风：照片级真人超写实,photorealistic, lifelike, ultra detailed)`，`(画风：3D国创,Chinese 3D animation style)`等,如果图片风格无法描述，可以返回`无法描述`,多张图片时，只输出一个综合的画风提示词，要求包含所有图片的共同风格特征，输出格式必须严格按照示例中的格式，必须包含`画风`二字，且必须使用括号括起来，括号内必须包含中文和英文的画风描述，并用逗号分隔，英文部分需要翻译成地道的英文提示词"#;

#[derive(Debug, FromRow, Serialize)]
pub struct ArtStyleRow {
    pub id: Uuid,
    #[serde(rename = "numeric_id")]
    pub legacy_id: i32,
    pub name: String,
    pub file_url: Option<String>,
    pub label: Option<String>,
    pub prompt: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ListArtStylesResponse {
    pub items: Vec<ArtStyleRow>,
    pub total: i64,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct CreateArtStyleBody {
    pub name: String,
    #[serde(default)]
    pub file_url: Option<String>,
    #[serde(default)]
    pub label: Option<String>,
    #[serde(default)]
    pub prompt: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ExtractArtStylePromptBody {
    pub images: Vec<String>,
}

#[derive(Debug, Serialize)]
pub struct ExtractArtStylePromptResponse {
    pub text: String,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct PatchArtStyleBody {
    #[serde(default)]
    pub name: Option<Value>,
    #[serde(default)]
    pub file_url: Option<Value>,
    #[serde(default)]
    pub label: Option<Value>,
    #[serde(default)]
    pub prompt: Option<Value>,
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/art-styles/extract-prompt",
            post(extract_style_prompt),
        )
        .route(
            "/api/v1/art-styles",
            get(list_art_styles).post(create_art_style),
        )
        .route(
            "/api/v1/art-styles/numeric/{numeric_id}",
            get(get_art_style_by_numeric_id)
                .patch(patch_art_style_by_numeric_id)
                .delete(delete_art_style_by_numeric_id),
        )
        .route(
            "/api/v1/art-styles/numeric/{numeric_id}/cover",
            get(get_art_style_cover_by_numeric_id),
        )
}

fn trim_opt(s: Option<String>) -> Option<String> {
    s.map(|v| v.trim().to_owned()).filter(|s| !s.is_empty())
}

#[derive(Debug, Clone)]
struct LocalArtStyleCover {
    bytes: Vec<u8>,
    ext: &'static str,
}

#[derive(Debug, FromRow)]
struct ArtStyleFileUrlRow {
    file_url: Option<String>,
}

fn is_http_url(s: &str) -> bool {
    s.starts_with("http://") || s.starts_with("https://")
}

fn art_style_cover_api_path(numeric_id: i32) -> String {
    format!("/api/v1/art-styles/numeric/{numeric_id}/cover")
}

fn parse_uploaded_cover(raw: &str) -> Result<Option<LocalArtStyleCover>, ApiError> {
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
    legacy_id: i32,
    ext: &str,
) -> PathBuf {
    root.join(owner_user_id.to_string())
        .join(format!("{legacy_id}.{ext}"))
}

fn existing_art_style_cover_paths(
    root: &FsPath,
    owner_user_id: Uuid,
    legacy_id: i32,
) -> [PathBuf; 3] {
    [
        art_style_cover_file_path(root, owner_user_id, legacy_id, "png"),
        art_style_cover_file_path(root, owner_user_id, legacy_id, "jpg"),
        art_style_cover_file_path(root, owner_user_id, legacy_id, "webp"),
    ]
}

async fn delete_local_art_style_cover_files(root: &FsPath, owner_user_id: Uuid, legacy_id: i32) {
    for path in existing_art_style_cover_paths(root, owner_user_id, legacy_id) {
        let _ = fs::remove_file(path).await;
    }
}

async fn persist_local_art_style_cover(
    root: &FsPath,
    owner_user_id: Uuid,
    legacy_id: i32,
    cover: &LocalArtStyleCover,
) -> Result<(), ApiError> {
    let dir = root.join(owner_user_id.to_string());
    fs::create_dir_all(&dir)
        .await
        .map_err(|e| ApiError::BadRequest(format!("art style cover mkdir failed: {e}")))?;
    delete_local_art_style_cover_files(root, owner_user_id, legacy_id).await;
    let path = art_style_cover_file_path(root, owner_user_id, legacy_id, cover.ext);
    fs::write(&path, &cover.bytes)
        .await
        .map_err(|e| ApiError::BadRequest(format!("art style cover write failed: {e}")))?;
    Ok(())
}

async fn extract_style_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ExtractArtStylePromptBody>,
) -> Result<Json<ExtractArtStylePromptResponse>, ApiError> {
    let _uid = require_user_uuid(&state, &headers)?;

    if body.images.is_empty() {
        return Err(ApiError::BadRequest("images must be non-empty".into()));
    }
    if body.images.len() > MAX_EXTRACT_IMAGES {
        return Err(ApiError::BadRequest(format!(
            "at most {MAX_EXTRACT_IMAGES} images"
        )));
    }

    let mut parts: Vec<Value> = Vec::with_capacity(body.images.len());
    for (i, raw) in body.images.iter().enumerate() {
        let s = raw.trim();
        if s.is_empty() {
            return Err(ApiError::BadRequest(format!("images[{i}] is empty")));
        }
        if s.len() > MAX_IMAGE_ENTRY_BYTES {
            return Err(ApiError::BadRequest(format!(
                "images[{i}] exceeds max length ({MAX_IMAGE_ENTRY_BYTES} bytes)"
            )));
        }
        parts.push(json!({
            "type": "image_url",
            "image_url": { "url": s }
        }));
    }

    let cfg = state.llm.as_ref().ok_or(ApiError::LlmNotConfigured)?;

    let messages = vec![
        json!({ "role": "system", "content": EXTRACT_STYLE_SYSTEM_PROMPT }),
        json!({ "role": "user", "content": parts }),
    ];

    let text = chat_completion_assistant_text(cfg, &state.http_client, messages)
        .await
        .map_err(|e| {
            tracing::warn!(error = %e, "extract_style_prompt");
            ApiError::Internal
        })?;

    Ok(Json(ExtractArtStylePromptResponse { text }))
}

async fn list_art_styles(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<ListArtStylesResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let total: i64 = sqlx::query_scalar(
        r#"SELECT COUNT(*)::bigint FROM app_art_style WHERE owner_user_id = $1"#,
    )
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let items = sqlx::query_as::<_, ArtStyleRow>(
        r#"
        SELECT id, legacy_id, name, file_url, label, prompt
        FROM app_art_style
        WHERE owner_user_id = $1
        ORDER BY legacy_id ASC
        LIMIT $2
        "#,
    )
    .bind(uid)
    .bind(MAX_ART_STYLE_LIST)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(ListArtStylesResponse { items, total }))
}

async fn create_art_style(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateArtStyleBody>,
) -> Result<(StatusCode, Json<ArtStyleRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let name = body.name.trim().to_string();
    if name.is_empty() {
        return Err(ApiError::BadRequest("name must not be empty".into()));
    }

    let file_url = trim_opt(body.file_url);
    let label = trim_opt(body.label);
    let prompt = trim_opt(body.prompt);
    let uploaded_cover = match file_url.as_deref() {
        Some(file_url) => parse_uploaded_cover(file_url)?,
        None => None,
    };
    if uploaded_cover.is_some() && state.local_art_style_cover_dir.is_none() {
        return Err(ApiError::NotImplemented(
            "TOONFLOW_LOCAL_ART_STYLE_COVER_DIR is not set; cannot persist art style base64 covers"
                .into(),
        ));
    }

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ART_STYLE_LEGACY)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_legacy: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(legacy_id), 0) + 1 FROM app_art_style"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let row = sqlx::query_as::<_, ArtStyleRow>(
        r#"
        INSERT INTO app_art_style (
          owner_user_id, legacy_id, name, file_url, label, prompt
        )
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id, legacy_id, name, file_url, label, prompt
        "#,
    )
    .bind(uid)
    .bind(next_legacy)
    .bind(&name)
    .bind(if uploaded_cover.is_some() {
        Some(art_style_cover_api_path(next_legacy))
    } else {
        file_url.clone()
    })
    .bind(&label)
    .bind(&prompt)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if let (Some(root), Some(cover)) = (
        state.local_art_style_cover_dir.as_deref(),
        uploaded_cover.as_ref(),
    ) {
        persist_local_art_style_cover(root, uid, next_legacy, cover).await?;
    }

    Ok((StatusCode::CREATED, Json(row)))
}

async fn get_art_style_by_numeric_id(
    State(state): State<AppState>,
    Path(numeric_id): Path<i32>,
    headers: HeaderMap,
) -> Result<Json<ArtStyleRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric_id must be positive".into()));
    }

    let row = sqlx::query_as::<_, ArtStyleRow>(
        r#"
        SELECT id, legacy_id, name, file_url, label, prompt
        FROM app_art_style
        WHERE owner_user_id = $1 AND legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

async fn patch_art_style_by_numeric_id(
    State(state): State<AppState>,
    Path(numeric_id): Path<i32>,
    headers: HeaderMap,
    Json(body): Json<PatchArtStyleBody>,
) -> Result<Json<ArtStyleRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric_id must be positive".into()));
    }

    let name_patch = parse_optional_text_field(body.name, "name")?;
    let file_url_patch = parse_optional_text_field(body.file_url, "file_url")?;
    let label_patch = parse_optional_text_field(body.label, "label")?;
    let prompt_patch = parse_optional_text_field(body.prompt, "prompt")?;

    if matches!(name_patch, FieldPatch::Absent)
        && matches!(file_url_patch, FieldPatch::Absent)
        && matches!(label_patch, FieldPatch::Absent)
        && matches!(prompt_patch, FieldPatch::Absent)
    {
        return Err(ApiError::BadRequest(
            "expected at least one of: name, file_url, label, prompt".into(),
        ));
    }

    let current = sqlx::query_as::<_, ArtStyleRow>(
        r#"
        SELECT id, legacy_id, name, file_url, label, prompt
        FROM app_art_style
        WHERE owner_user_id = $1 AND legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let new_name = match &name_patch {
        FieldPatch::Absent => current.name.clone(),
        FieldPatch::Set(v) => v.clone().unwrap_or_default(),
    };
    if new_name.trim().is_empty() {
        return Err(ApiError::BadRequest("name cannot be empty".into()));
    }

    let new_file_url = match &file_url_patch {
        FieldPatch::Absent => current.file_url.clone(),
        FieldPatch::Set(v) => v.clone(),
    };
    let new_label = match &label_patch {
        FieldPatch::Absent => current.label.clone(),
        FieldPatch::Set(v) => v.clone(),
    };
    let new_prompt = match &prompt_patch {
        FieldPatch::Absent => current.prompt.clone(),
        FieldPatch::Set(v) => v.clone(),
    };
    let uploaded_cover = match &new_file_url {
        Some(file_url) => parse_uploaded_cover(file_url)?,
        None => None,
    };
    if uploaded_cover.is_some() && state.local_art_style_cover_dir.is_none() {
        return Err(ApiError::NotImplemented(
            "TOONFLOW_LOCAL_ART_STYLE_COVER_DIR is not set; cannot persist art style base64 covers"
                .into(),
        ));
    }
    let stored_file_url = if uploaded_cover.is_some() {
        Some(art_style_cover_api_path(numeric_id))
    } else {
        new_file_url.clone()
    };

    let row = sqlx::query_as::<_, ArtStyleRow>(
        r#"
        UPDATE app_art_style
        SET name = $1,
            file_url = $2,
            label = $3,
            prompt = $4,
            updated_at = NOW()
        WHERE owner_user_id = $5 AND legacy_id = $6
        RETURNING id, legacy_id, name, file_url, label, prompt
        "#,
    )
    .bind(&new_name)
    .bind(&stored_file_url)
    .bind(&new_label)
    .bind(&new_prompt)
    .bind(uid)
    .bind(numeric_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if let Some(root) = state.local_art_style_cover_dir.as_deref() {
        if let Some(cover) = uploaded_cover.as_ref() {
            persist_local_art_style_cover(root, uid, numeric_id, cover).await?;
        } else if matches!(file_url_patch, FieldPatch::Set(_))
            && current.file_url.as_deref() == Some(art_style_cover_api_path(numeric_id).as_str())
            && stored_file_url.as_deref() != Some(art_style_cover_api_path(numeric_id).as_str())
        {
            delete_local_art_style_cover_files(root, uid, numeric_id).await;
        }
    }

    Ok(Json(row))
}

async fn delete_art_style_by_numeric_id(
    State(state): State<AppState>,
    Path(numeric_id): Path<i32>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric_id must be positive".into()));
    }

    let res =
        sqlx::query(r#"DELETE FROM app_art_style WHERE owner_user_id = $1 AND legacy_id = $2"#)
            .bind(uid)
            .bind(numeric_id)
            .execute(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    if let Some(root) = state.local_art_style_cover_dir.as_deref() {
        delete_local_art_style_cover_files(root, uid, numeric_id).await;
    }

    Ok(StatusCode::NO_CONTENT)
}

async fn get_art_style_cover_by_numeric_id(
    State(state): State<AppState>,
    Path(numeric_id): Path<i32>,
    headers: HeaderMap,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric_id must be positive".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let row = sqlx::query_as::<_, ArtStyleFileUrlRow>(
        r#"
        SELECT file_url
        FROM app_art_style
        WHERE owner_user_id = $1 AND legacy_id = $2
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn create_art_style_body_accepts_minimal() {
        let j = serde_json::json!({ "name": "test" });
        let b: CreateArtStyleBody = serde_json::from_value(j).unwrap();
        assert_eq!(b.name, "test");
    }

    #[test]
    fn patch_art_style_body_rejects_unknown_fields() {
        let j = serde_json::json!({ "name": "x", "extra": 1 });
        assert!(serde_json::from_value::<PatchArtStyleBody>(j).is_err());
    }

    #[test]
    fn extract_art_style_prompt_body_accepts_images() {
        let j = serde_json::json!({ "images": ["https://example.com/a.png"] });
        let b: ExtractArtStylePromptBody = serde_json::from_value(j).unwrap();
        assert_eq!(b.images.len(), 1);
    }

    #[test]
    fn extract_art_style_prompt_body_rejects_unknown_fields() {
        let j = serde_json::json!({ "images": [], "extra": 1 });
        assert!(serde_json::from_value::<ExtractArtStylePromptBody>(j).is_err());
    }

    #[test]
    fn parse_uploaded_cover_accepts_png_data_uri() {
        let parsed = parse_uploaded_cover("data:image/png;base64,AA==")
            .expect("parse")
            .expect("cover");
        assert_eq!(parsed.ext, "png");
        assert_eq!(parsed.bytes, vec![0]);
    }

    #[test]
    fn parse_uploaded_cover_treats_http_url_as_passthrough() {
        assert!(parse_uploaded_cover("https://example.com/cover.png")
            .expect("parse")
            .is_none());
    }

    #[test]
    fn parse_uploaded_cover_rejects_non_image_data_uri() {
        let err = parse_uploaded_cover("data:text/plain;base64,AA==").expect_err("bad mime");
        assert!(matches!(err, ApiError::BadRequest(_)));
    }
}
