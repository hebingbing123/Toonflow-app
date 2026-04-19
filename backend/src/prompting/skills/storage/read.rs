use std::path::Path;

use super::super::{SkillContentResponse, MAX_SKILL_BINARY_BYTES, MAX_SKILL_BYTES};
use super::errors::SkillReadError;
use super::paths::{safe_join_under_root, skills_root};

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
