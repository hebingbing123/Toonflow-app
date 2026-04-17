use std::path::PathBuf;

use crate::error::ApiError;
use crate::prompting::skills::skills_root;

use super::slots::NAME_RULE_MSG;

pub(super) fn is_safe_style_component(name: &str) -> bool {
    !name.is_empty()
        && name != "."
        && name != ".."
        && !name.contains('/')
        && !name.contains('\\')
        && !name.contains('\0')
}

pub(super) fn validate_manual_folder_name(key: &str) -> Result<(), ApiError> {
    if !key.is_empty()
        && key != "."
        && key != ".."
        && !key.contains('/')
        && !key.contains('\\')
        && !key.contains('\0')
        && !key.chars().all(|c| c.is_ascii_digit())
    {
        Ok(())
    } else {
        Err(ApiError::BadRequest(NAME_RULE_MSG.into()))
    }
}

pub(super) fn art_skills_style_dir(style_path: &str) -> Result<PathBuf, ApiError> {
    validate_manual_folder_name(style_path)?;
    let root = skills_root();
    if !root.is_dir() {
        return Err(ApiError::BadRequest(
            "skills directory missing (expected backend/data/skills)".into(),
        ));
    }
    Ok(root.join("art_skills").join(style_path))
}
