//! 风格键校验与 `story_skills/{key}` 目录解析。

use std::path::PathBuf;

use crate::error::ApiError;
use crate::prompting::skills::skills_root;

pub(super) fn is_safe_style_component(name: &str) -> bool {
    !name.is_empty()
        && name != "."
        && name != ".."
        && !name.contains('/')
        && !name.contains('\\')
        && !name.contains('\0')
        && !name.chars().all(|c| c.is_ascii_digit())
}

pub(crate) fn validate_style_key(msg_zh: &'static str, key: &str) -> Result<(), ApiError> {
    if is_safe_style_component(key) {
        Ok(())
    } else {
        Err(ApiError::BadRequest(msg_zh.into()))
    }
}

pub(crate) fn story_manual_dir(director_manual: &str) -> Result<PathBuf, ApiError> {
    validate_style_key("名称不能包含路径分隔符或为纯数字", director_manual)?;
    let root = skills_root();
    if !root.is_dir() {
        return Err(ApiError::BadRequest(
            "skills directory missing (expected backend/data/skills)".into(),
        ));
    }
    Ok(root.join("story_skills").join(director_manual))
}
