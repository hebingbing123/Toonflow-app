//! HTTP surface for Markdown skills under `backend/data/skills/`.
//! Paths are relative to that directory; `..` segments are rejected.
//! **`PUT /api/v1/skills/content`** overwrites an **existing** file only (parity with legacy **`saveSkillContent`**).
//! **`POST /api/v1/skills/content`** creates a **new** file (parent directories are created under `data/skills`); existing files → **409**.
//! **`DELETE /api/v1/skills/content?path=`** removes one **file** (not directories).

use std::path::{Path, PathBuf};

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

/// Filesystem errors when resolving or reading a skill (shared by HTTP and Harness `skills.read`).
#[derive(Debug)]
pub(crate) enum SkillReadError {
    BadPath(String),
    SkillsDirMissing,
    NotFound,
    TooLarge,
    TooLargeBinary,
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
            SkillReadError::TooLargeBinary => ApiError::BadRequest(format!(
                "skill binary file exceeds {MAX_SKILL_BINARY_BYTES} bytes"
            )),
            SkillReadError::Io(m) => ApiError::BadRequest(m),
        }
    }
}

/// Write errors (existing file required; same path rules as read).
#[derive(Debug)]
pub(crate) enum SkillWriteError {
    BadPath(String),
    SkillsDirMissing,
    /// Legacy **`saveSkillContent`** returned **400** when the file did not exist.
    FileMissing,
    TooLarge,
    Io(String),
}

impl SkillWriteError {
    fn into_api_error(self) -> ApiError {
        match self {
            SkillWriteError::BadPath(m) => ApiError::BadRequest(m),
            SkillWriteError::SkillsDirMissing => ApiError::BadRequest(
                "skills directory missing (expected backend/data/skills)".into(),
            ),
            SkillWriteError::FileMissing => {
                ApiError::BadRequest("skill file does not exist".into())
            }
            SkillWriteError::TooLarge => {
                ApiError::BadRequest(format!("skill content exceeds {MAX_SKILL_BYTES} bytes"))
            }
            SkillWriteError::Io(m) => ApiError::BadRequest(m),
        }
    }
}

#[derive(Debug)]
pub(crate) enum SkillCreateError {
    BadPath(String),
    SkillsDirMissing,
    AlreadyExists,
    TooLarge,
    Io(String),
}

impl SkillCreateError {
    fn into_api_error(self) -> ApiError {
        match self {
            SkillCreateError::BadPath(m) => ApiError::BadRequest(m),
            SkillCreateError::SkillsDirMissing => ApiError::BadRequest(
                "skills directory missing (expected backend/data/skills)".into(),
            ),
            SkillCreateError::AlreadyExists => {
                ApiError::Conflict("skill file already exists".into())
            }
            SkillCreateError::TooLarge => {
                ApiError::BadRequest(format!("skill content exceeds {MAX_SKILL_BYTES} bytes"))
            }
            SkillCreateError::Io(m) => ApiError::BadRequest(m),
        }
    }
}

#[derive(Debug)]
pub(crate) enum SkillDeleteError {
    BadPath(String),
    SkillsDirMissing,
    NotFound,
    NotAFile,
    Io(String),
}

impl SkillDeleteError {
    fn into_api_error(self) -> ApiError {
        match self {
            SkillDeleteError::BadPath(m) => ApiError::BadRequest(m),
            SkillDeleteError::SkillsDirMissing => ApiError::BadRequest(
                "skills directory missing (expected backend/data/skills)".into(),
            ),
            SkillDeleteError::NotFound => ApiError::NotFound,
            SkillDeleteError::NotAFile => ApiError::BadRequest("path is not a regular file".into()),
            SkillDeleteError::Io(m) => ApiError::BadRequest(m),
        }
    }
}

pub(crate) fn skills_root() -> PathBuf {
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

fn mime_for_skill_image(path: &std::path::Path) -> Option<&'static str> {
    let ext = path.extension()?.to_str()?;
    Some(match ext.to_ascii_lowercase().as_str() {
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "svg" => "image/svg+xml",
        _ => return None,
    })
}

/// Read a regular file under `data/skills` as bytes (images only). Same path safety as Markdown reads.
pub(crate) fn read_skill_binary(relative: &str) -> Result<(Vec<u8>, &'static str), SkillReadError> {
    let root = skills_root();
    if !root.is_dir() {
        return Err(SkillReadError::SkillsDirMissing);
    }
    let resolved = safe_join_under_root(&root, relative)?;
    if !resolved.is_file() {
        return Err(SkillReadError::NotFound);
    }
    let mime = mime_for_skill_image(&resolved).ok_or_else(|| {
        SkillReadError::BadPath(
            "only image files are allowed (png, jpg, jpeg, gif, webp, svg)".into(),
        )
    })?;
    let meta = std::fs::metadata(&resolved)
        .map_err(|e| SkillReadError::Io(format!("cannot stat skill file: {e}")))?;
    if meta.len() > MAX_SKILL_BINARY_BYTES {
        return Err(SkillReadError::TooLargeBinary);
    }
    let content = std::fs::read(&resolved)
        .map_err(|e| SkillReadError::Io(format!("cannot read skill file: {e}")))?;
    Ok((content, mime))
}

/// Overwrite an existing skill file under `root` (used by HTTP and unit tests).
pub(crate) fn write_skill_at(
    root: &Path,
    relative: &str,
    content: &str,
) -> Result<SkillContentResponse, SkillWriteError> {
    if !root.is_dir() {
        return Err(SkillWriteError::SkillsDirMissing);
    }
    let resolved = safe_join_under_root(root, relative.trim()).map_err(|e| match e {
        SkillReadError::BadPath(m) => SkillWriteError::BadPath(m),
        SkillReadError::SkillsDirMissing
        | SkillReadError::NotFound
        | SkillReadError::TooLarge
        | SkillReadError::TooLargeBinary
        | SkillReadError::Io(_) => SkillWriteError::BadPath("invalid skill path".into()),
    })?;
    if !resolved.is_file() {
        return Err(SkillWriteError::FileMissing);
    }
    let n = content.len() as u64;
    if n > MAX_SKILL_BYTES {
        return Err(SkillWriteError::TooLarge);
    }
    std::fs::write(&resolved, content).map_err(|e| SkillWriteError::Io(e.to_string()))?;
    let rel = resolved
        .strip_prefix(root)
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_else(|_| relative.trim().to_string());
    Ok(SkillContentResponse {
        path: rel,
        content: content.to_string(),
    })
}

fn write_skill_markdown(
    relative: &str,
    content: &str,
) -> Result<SkillContentResponse, SkillWriteError> {
    write_skill_at(&skills_root(), relative, content)
}

/// Create a new skill file under `root` (parent dirs created). Fails if path exists.
pub(crate) fn create_skill_at(
    root: &Path,
    relative: &str,
    content: &str,
) -> Result<SkillContentResponse, SkillCreateError> {
    if !root.is_dir() {
        return Err(SkillCreateError::SkillsDirMissing);
    }
    let rel = relative.trim();
    if rel.is_empty() {
        return Err(SkillCreateError::BadPath("path must not be empty".into()));
    }
    let resolved = safe_join_under_root(root, rel).map_err(|e| match e {
        SkillReadError::BadPath(m) => SkillCreateError::BadPath(m),
        SkillReadError::SkillsDirMissing
        | SkillReadError::NotFound
        | SkillReadError::TooLarge
        | SkillReadError::TooLargeBinary
        | SkillReadError::Io(_) => SkillCreateError::BadPath("invalid skill path".into()),
    })?;
    if resolved.exists() {
        return if resolved.is_file() {
            Err(SkillCreateError::AlreadyExists)
        } else {
            Err(SkillCreateError::BadPath(
                "path exists and is not a file".into(),
            ))
        };
    }
    let n = content.len() as u64;
    if n > MAX_SKILL_BYTES {
        return Err(SkillCreateError::TooLarge);
    }
    if let Some(parent) = resolved.parent() {
        std::fs::create_dir_all(parent).map_err(|e| SkillCreateError::Io(e.to_string()))?;
    }
    std::fs::write(&resolved, content).map_err(|e| SkillCreateError::Io(e.to_string()))?;
    let rel_out = resolved
        .strip_prefix(root)
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_else(|_| rel.to_string());
    Ok(SkillContentResponse {
        path: rel_out,
        content: content.to_string(),
    })
}

fn create_skill_markdown(
    relative: &str,
    content: &str,
) -> Result<SkillContentResponse, SkillCreateError> {
    create_skill_at(&skills_root(), relative, content)
}

pub(crate) fn delete_skill_at(root: &Path, relative: &str) -> Result<(), SkillDeleteError> {
    if !root.is_dir() {
        return Err(SkillDeleteError::SkillsDirMissing);
    }
    let rel = relative.trim();
    if rel.is_empty() {
        return Err(SkillDeleteError::BadPath("path must not be empty".into()));
    }
    let resolved = safe_join_under_root(root, rel).map_err(|e| match e {
        SkillReadError::BadPath(m) => SkillDeleteError::BadPath(m),
        SkillReadError::SkillsDirMissing
        | SkillReadError::NotFound
        | SkillReadError::TooLarge
        | SkillReadError::TooLargeBinary
        | SkillReadError::Io(_) => SkillDeleteError::BadPath("invalid skill path".into()),
    })?;
    if !resolved.exists() {
        return Err(SkillDeleteError::NotFound);
    }
    if !resolved.is_file() {
        return Err(SkillDeleteError::NotAFile);
    }
    std::fs::remove_file(&resolved).map_err(|e| SkillDeleteError::Io(e.to_string()))?;
    Ok(())
}

fn delete_skill_markdown(relative: &str) -> Result<(), SkillDeleteError> {
    delete_skill_at(&skills_root(), relative)
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
    let _ = require_user_uuid(&state, &headers)?;
    let doc =
        write_skill_markdown(&body.path, &body.content).map_err(SkillWriteError::into_api_error)?;
    Ok(Json(doc))
}

async fn post_skill_content(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SkillContentBody>,
) -> Result<impl IntoResponse, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let doc = create_skill_markdown(&body.path, &body.content)
        .map_err(SkillCreateError::into_api_error)?;
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
mod tests {
    use super::*;
    use std::path::Path;

    #[test]
    fn skill_content_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<SkillContentBody>(r#"{"path":"a.md","content":"x","extra":1}"#);
        assert!(err.is_err());
    }

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

    #[test]
    fn write_skill_at_updates_existing_file() {
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        std::fs::write(root.join("a.md"), "old").unwrap();
        let out = super::write_skill_at(root, "a.md", "new").unwrap();
        assert_eq!(out.path, "a.md");
        assert_eq!(out.content, "new");
        assert_eq!(std::fs::read_to_string(root.join("a.md")).unwrap(), "new");
    }

    #[test]
    fn write_skill_at_rejects_missing_file() {
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        assert!(matches!(
            super::write_skill_at(root, "nope.md", "x"),
            Err(super::SkillWriteError::FileMissing)
        ));
    }

    #[test]
    fn create_skill_at_writes_nested_file() {
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        let out = super::create_skill_at(root, "nested/x.md", "hi").unwrap();
        assert_eq!(out.path, "nested/x.md");
        assert_eq!(out.content, "hi");
        assert_eq!(
            std::fs::read_to_string(root.join("nested/x.md")).unwrap(),
            "hi"
        );
    }

    #[test]
    fn create_skill_at_rejects_existing_file() {
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        std::fs::write(root.join("b.md"), "1").unwrap();
        assert!(matches!(
            super::create_skill_at(root, "b.md", "2"),
            Err(super::SkillCreateError::AlreadyExists)
        ));
    }

    #[test]
    fn delete_skill_at_removes_file() {
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        std::fs::write(root.join("d.md"), "z").unwrap();
        super::delete_skill_at(root, "d.md").unwrap();
        assert!(!root.join("d.md").exists());
    }

    #[test]
    fn delete_skill_at_not_found() {
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        assert!(matches!(
            super::delete_skill_at(root, "gone.md"),
            Err(super::SkillDeleteError::NotFound)
        ));
    }

    #[test]
    fn read_skill_binary_smoke_fixture_is_png() {
        let got = super::read_skill_binary("_smoke/binary_probe.png").unwrap();
        assert_eq!(got.1, "image/png");
        assert!(got.0.starts_with(&[0x89, b'P', b'N', b'G']));
    }

    #[test]
    fn read_skill_binary_rejects_markdown_extension() {
        assert!(matches!(
            super::read_skill_binary("script_execution_script.md"),
            Err(super::SkillReadError::BadPath(_))
        ));
    }
}
