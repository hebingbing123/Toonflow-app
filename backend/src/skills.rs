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
use crate::harness::tools::ToolRegistry;
use crate::state::AppState;

const MAX_SKILL_BYTES: u64 = 2_000_000;
const MAX_SKILL_FILES: usize = 20_000;

fn skills_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("data/skills")
}

/// Reject `..` and absolute-ish segments; build path under `root`.
fn safe_join_under_root(root: &Path, relative: &str) -> Result<PathBuf, ApiError> {
    let mut p = root.to_path_buf();
    for segment in relative.split(['/', '\\']) {
        if segment.is_empty() || segment == "." {
            continue;
        }
        if segment == ".." {
            return Err(ApiError::BadRequest(
                "path must not contain parent segments".into(),
            ));
        }
        p.push(segment);
    }
    Ok(p)
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

#[derive(Serialize)]
pub struct HarnessToolsResponse {
    pub tools: Vec<String>,
}

#[derive(Deserialize)]
pub struct SkillContentQuery {
    /// Relative path under `data/skills`, e.g. `script_execution_script.md`
    pub path: String,
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/skills", get(list_skills))
        .route("/api/v1/skills/content", get(get_skill_content))
        .route("/api/v1/harness/tools", get(list_harness_tools))
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
    let root = skills_root();
    let resolved = safe_join_under_root(&root, q.path.trim())?;
    if !resolved.is_file() {
        return Err(ApiError::NotFound);
    }
    let meta = std::fs::metadata(&resolved)
        .map_err(|e| ApiError::BadRequest(format!("cannot stat skill: {e}")))?;
    if meta.len() > MAX_SKILL_BYTES {
        return Err(ApiError::BadRequest(format!(
            "skill file exceeds {MAX_SKILL_BYTES} bytes"
        )));
    }
    let content = std::fs::read_to_string(&resolved)
        .map_err(|e| ApiError::BadRequest(format!("cannot read skill: {e}")))?;
    let rel = resolved
        .strip_prefix(&root)
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_else(|_| q.path.clone());
    Ok(Json(SkillContentResponse { path: rel, content }))
}

async fn list_harness_tools(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<HarnessToolsResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let reg = ToolRegistry::default();
    Ok(Json(HarnessToolsResponse {
        tools: reg.names().iter().map(|s| (*s).to_string()).collect(),
    }))
}
