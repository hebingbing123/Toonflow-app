//! Markdown 技能的 HTTP 接口（位于 `backend/data/skills/` 下）。
//!
//! 路径相对于该目录；拒绝 `..` 段。
//! `PUT /api/v1/skills/content` 仅覆盖**现有**文件（与遗留 `saveSkillContent` 兼容）。
//! `POST /api/v1/skills/content` 创建**新**文件（在 `data/skills` 下创建父目录）；现有文件 → **409**。
//! `DELETE /api/v1/skills/content?path=` 删除一个**文件**（不删除目录）。

use axum::{
    body::Body,
    extract::{Query, State},
    http::{header, HeaderMap, StatusCode},
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use walkdir::WalkDir;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

const MAX_SKILL_BYTES: u64 = 2_000_000;
/// Bundled reference images (e.g. visual manual) may be larger than Markdown skills.
const MAX_SKILL_BINARY_BYTES: u64 = 25_000_000;
const MAX_SKILL_FILES: usize = 20_000;

mod change_notify;
mod storage;

use storage::{create_skill_markdown, delete_skill_markdown, write_skill_markdown};

#[allow(unused_imports)]
pub(crate) use storage::safe_join_under_root;

#[allow(unused_imports)]
pub(crate) use storage::{
    create_skill_at, delete_skill_at, read_skill_binary, read_skill_markdown,
    read_skill_markdown_section, skills_root, write_skill_at, SkillCreateError, SkillDeleteError,
    SkillReadError, SkillWriteError,
};

#[derive(Serialize)]
pub struct SkillFileMeta {
    pub path: String,
    pub size_bytes: u64,
}

#[derive(Serialize)]
pub struct SkillContentResponse {
    pub path: String,
    pub content: String,
}

/// Aggregate over `*.md` under `data/skills` (same walk cap as [`list_skills`]).
#[derive(Serialize)]
pub struct SkillsSummaryResponse {
    pub markdown_file_count: u64,
    pub total_bytes: u64,
}

#[derive(Deserialize)]
pub struct SkillContentQuery {
    /// Relative path under `data/skills`, e.g. `script_execution_script.md`
    pub path: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SkillContentBody {
    pub path: String,
    pub content: String,
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/skills/summary", get(skills_summary))
        .route("/api/v1/skills", get(list_skills))
        .route("/api/v1/skills/binary", get(get_skill_binary))
        .route(
            "/api/v1/skills/content",
            get(get_skill_content)
                .put(put_skill_content)
                .post(post_skill_content)
                .delete(delete_skill_content),
        )
}

/// Walk `data/skills` for `*.md` files; stops after [`MAX_SKILL_FILES`] matches (same rule as list).
fn scan_skill_markdown_aggregate() -> Result<SkillsSummaryResponse, ApiError> {
    let root = skills_root();
    if !root.is_dir() {
        return Err(ApiError::BadRequest(
            "skills directory missing (expected backend/data/skills)".into(),
        ));
    }
    let mut n: usize = 0;
    let mut total: u64 = 0;
    for entry in WalkDir::new(&root).into_iter().filter_map(|e| e.ok()) {
        if !entry.file_type().is_file() {
            continue;
        }
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("md") {
            continue;
        }
        let size = entry.metadata().map(|m| m.len()).unwrap_or(0);
        n += 1;
        total = total.saturating_add(size);
        if n >= MAX_SKILL_FILES {
            break;
        }
    }
    Ok(SkillsSummaryResponse {
        markdown_file_count: n as u64,
        total_bytes: total,
    })
}

async fn skills_summary(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<SkillsSummaryResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    Ok(Json(scan_skill_markdown_aggregate()?))
}

async fn list_skills(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<SkillFileMeta>>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let root = skills_root();
    if !root.is_dir() {
        return Err(ApiError::BadRequest(
            "skills directory missing (expected backend/data/skills)".into(),
        ));
    }

    let mut out = Vec::new();
    for entry in WalkDir::new(&root).into_iter().filter_map(|e| e.ok()) {
        if !entry.file_type().is_file() {
            continue;
        }
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("md") {
            continue;
        }
        let rel = path
            .strip_prefix(&root)
            .map_err(|_| ApiError::BadRequest("could not relativize skill path".into()))?;
        let rel_s = rel.to_string_lossy().to_string();
        let size = entry.metadata().map(|m| m.len()).unwrap_or(0);
        out.push(SkillFileMeta {
            path: rel_s,
            size_bytes: size,
        });
        if out.len() >= MAX_SKILL_FILES {
            break;
        }
    }

    out.sort_by(|a, b| a.path.cmp(&b.path));
    Ok(Json(out))
}

async fn get_skill_content(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<SkillContentQuery>,
) -> Result<Json<SkillContentResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let doc = read_skill_markdown(q.path.trim()).map_err(SkillReadError::into_api_error)?;
    Ok(Json(doc))
}

async fn get_skill_binary(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<SkillContentQuery>,
) -> Result<axum::response::Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let (bytes, mime) = read_skill_binary(q.path.trim()).map_err(SkillReadError::into_api_error)?;
    axum::response::Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, mime)
        .body(Body::from(bytes))
        .map_err(|_| ApiError::Internal)
}

async fn put_skill_content(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SkillContentBody>,
) -> Result<Json<SkillContentResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    // 读取旧内容（用于版本记录的 hash_before）
    let old_content = read_skill_markdown(body.path.trim())
        .ok()
        .map(|d| d.content);

    let doc =
        write_skill_markdown(&body.path, &body.content).map_err(SkillWriteError::into_api_error)?;

    // 写入成功后自动记录版本（需求 24.1, 24.2）
    // pool.clone() 是 Arc 内部 clone，开销极低
    if let Ok(pool) = state.require_pool() {
        let pool = pool.clone();
        let path = doc.path.clone();
        let content = doc.content.clone();
        let old = old_content;
        let changed_at_ms = chrono::Utc::now().timestamp_millis();
        tokio::spawn(async move {
            if let Err(e) = crate::prompting::skill_versions::record_skill_version(
                &pool,
                &path,
                old.as_deref(),
                &content,
                Some(uid),
                None,
            )
            .await
            {
                tracing::warn!(error = %e, path = %path, "failed to record skill version");
            }
            if let Err(e) = change_notify::notify_skill_change(&pool, &path, changed_at_ms).await {
                tracing::warn!(error = ?e, path = %path, "failed to notify skill change");
            }
        });
    }

    Ok(Json(doc))
}

async fn post_skill_content(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SkillContentBody>,
) -> Result<impl IntoResponse, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let doc = create_skill_markdown(&body.path, &body.content)
        .map_err(SkillCreateError::into_api_error)?;

    // 新建文件后自动记录版本（需求 24.1, 24.2）
    if let Ok(pool) = state.require_pool() {
        let pool = pool.clone();
        let path = doc.path.clone();
        let content = doc.content.clone();
        let changed_at_ms = chrono::Utc::now().timestamp_millis();
        tokio::spawn(async move {
            if let Err(e) = crate::prompting::skill_versions::record_skill_version(
                &pool,
                &path,
                None, // 新建文件，无旧内容
                &content,
                Some(uid),
                Some("新建技能文件"),
            )
            .await
            {
                tracing::warn!(error = %e, path = %path, "failed to record skill version on create");
            }
            if let Err(e) = change_notify::notify_skill_change(&pool, &path, changed_at_ms).await {
                tracing::warn!(error = ?e, path = %path, "failed to notify created skill change");
            }
        });
    }

    Ok((StatusCode::CREATED, Json(doc)))
}

async fn delete_skill_content(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<SkillContentQuery>,
) -> Result<StatusCode, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    delete_skill_markdown(q.path.trim()).map_err(SkillDeleteError::into_api_error)?;
    Ok(StatusCode::NO_CONTENT)
}

#[cfg(test)]
mod tests;
