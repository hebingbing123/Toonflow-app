use std::path::Path;

use super::super::{SkillContentResponse, MAX_SKILL_BYTES};
use super::errors::{SkillCreateError, SkillDeleteError, SkillReadError, SkillWriteError};
use super::paths::{safe_join_under_root, skills_root};

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
        | SkillReadError::SectionNotFound(_)
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
        | SkillReadError::SectionNotFound(_)
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
        | SkillReadError::SectionNotFound(_)
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
