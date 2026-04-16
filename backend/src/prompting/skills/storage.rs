use std::path::{Path, PathBuf};

use crate::error::ApiError;

use super::{SkillContentResponse, MAX_SKILL_BINARY_BYTES, MAX_SKILL_BYTES};

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
    pub(crate) fn into_api_error(self) -> ApiError {
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
    /// Electron-era `saveSkillContent` returned 400 when the file did not exist.
    FileMissing,
    TooLarge,
    Io(String),
}

impl SkillWriteError {
    pub(crate) fn into_api_error(self) -> ApiError {
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
    pub(crate) fn into_api_error(self) -> ApiError {
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
    pub(crate) fn into_api_error(self) -> ApiError {
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
pub(crate) fn safe_join_under_root(root: &Path, relative: &str) -> Result<PathBuf, SkillReadError> {
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

fn mime_for_skill_image(path: &Path) -> Option<&'static str> {
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

pub(crate) fn write_skill_markdown(
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

pub(crate) fn create_skill_markdown(
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

pub(crate) fn delete_skill_markdown(relative: &str) -> Result<(), SkillDeleteError> {
    delete_skill_at(&skills_root(), relative)
}
