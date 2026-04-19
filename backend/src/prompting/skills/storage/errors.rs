use crate::error::ApiError;

use super::super::{MAX_SKILL_BINARY_BYTES, MAX_SKILL_BYTES};

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
