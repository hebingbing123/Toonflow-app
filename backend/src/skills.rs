//! Read-only HTTP surface for Markdown skills under `backend/data/skills/`.
//! Paths are relative to that directory; `..` segments are rejected.

use std::path::{Path, PathBuf};

use axum::{
    extract::{Query, State},
    http::HeaderMap,
    routing::get,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use walkdir::WalkDir;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

const MAX_SKILL_BYTES: u64 = 2_000_000;
const MAX_SKILL_FILES: usize = 20_000;

/// Filesystem errors when resolving or reading a skill (shared by HTTP and Harness `skills.read`).
#[derive(Debug)]
pub(crate) enum SkillReadError {
    BadPath(String),
    SkillsDirMissing,
    NotFound,
    TooLarge,
    Io(String),
}

impl SkillReadError {
    fn into_api_error(self) -> ApiError {
        match self {
            SkillReadError::BadPath(m) => ApiError::BadRequest(m),
            SkillReadError::SkillsDirMissing => ApiError::BadRequest(
                "skills directory missing (expected backend/data/skills)".into(),
            ),
            SkillReadError::NotFound => ApiError::NotFound,
            SkillReadError::TooLarge => {
                ApiError::BadRequest(format!("skill file exceeds {MAX_SKILL_BYTES} bytes"))
            }
            SkillReadError::Io(m) => ApiError::BadRequest(m),
        }
    }
}

fn skills_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("data/skills")
}

/// Reject `..` and absolute-ish segments; build path under `root`.
fn safe_join_under_root(root: &Path, relative: &str) -> Result<PathBuf, SkillReadError> {
    let mut p = root.to_path_buf();
    for segment in relative.split(['/', '\\']) {
        if segment.is_empty() || segment == "." {
            continue;
        }
        if segment == ".." {
            return Err(SkillReadError::BadPath(
                "path must not contain parent segments".into(),
            ));
        }
        p.push(segment);
    }
    Ok(p)
}

/// Read a single Markdown skill by path relative to `data/skills` (same rules as HTTP `GET .../skills/content`).
pub(crate) fn read_skill_markdown(relative: &str) -> Result<SkillContentResponse, SkillReadError> {
    let root = skills_root();
    if !root.is_dir() {
        return Err(SkillReadError::SkillsDirMissing);
    }
    let resolved = safe_join_under_root(&root, relative)?;
    if !resolved.is_file() {
        return Err(SkillReadError::NotFound);
    }
    let meta = std::fs::metadata(&resolved)
        .map_err(|e| SkillReadError::Io(format!("cannot stat skill: {e}")))?;
    if meta.len() > MAX_SKILL_BYTES {
        return Err(SkillReadError::TooLarge);
    }
    let content = std::fs::read_to_string(&resolved)
        .map_err(|e| SkillReadError::Io(format!("cannot read skill: {e}")))?;
    let rel = resolved
        .strip_prefix(&root)
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_else(|_| relative.to_string());
    Ok(SkillContentResponse { path: rel, content })
}

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

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/skills/summary", get(skills_summary))
        .route("/api/v1/skills", get(list_skills))
        .route("/api/v1/skills/content", get(get_skill_content))
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    #[test]
    fn safe_join_rejects_parent_segment() {
        let root = Path::new("/tmp/skills-root");
        assert!(matches!(
            safe_join_under_root(root, ".."),
            Err(SkillReadError::BadPath(_))
        ));
        assert!(matches!(
            safe_join_under_root(root, "legit/../nope.md"),
            Err(SkillReadError::BadPath(_))
        ));
    }

    #[test]
    fn safe_join_builds_under_root() {
        let root = Path::new("/tmp/skills-root");
        let p = safe_join_under_root(root, "dir/script.md").unwrap();
        assert!(p.ends_with("dir/script.md"));
    }
}
