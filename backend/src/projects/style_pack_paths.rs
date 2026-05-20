//! Normalize and validate project `art_style_pack` / `story_style_pack` paths.

use crate::error::ApiError;
use crate::http_kit::json_patch::FieldPatch;
use crate::prompting::skills::skills_root;

/// Canonical storage form: `art_skills/{style_key}`.
pub fn normalize_art_style_pack_path(raw: &str) -> String {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    if trimmed.starts_with("art_skills/") {
        trimmed.to_string()
    } else {
        format!("art_skills/{trimmed}")
    }
}

/// Canonical storage form: `story_skills/{genre_key}`.
pub fn normalize_story_style_pack_path(raw: &str) -> String {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    if trimmed.starts_with("story_skills/") {
        trimmed.to_string()
    } else {
        format!("story_skills/{trimmed}")
    }
}

fn pack_directory_exists(relative: &str) -> bool {
    skills_root().join(relative).is_dir()
}

/// Validates bundled art pack exists; returns normalized path for persistence.
pub fn validate_art_style_pack_set(value: &str) -> Result<String, ApiError> {
    let normalized = normalize_art_style_pack_path(value);
    if normalized.is_empty() {
        return Err(ApiError::BadRequest(
            "artStylePack cannot be empty when set".into(),
        ));
    }
    if !pack_directory_exists(&normalized) {
        return Err(ApiError::BadRequest(format!(
            "unknown art style pack: {value}"
        )));
    }
    Ok(normalized)
}

/// Validates bundled story pack exists; returns normalized path for persistence.
pub fn validate_story_style_pack_set(value: &str) -> Result<String, ApiError> {
    let normalized = normalize_story_style_pack_path(value);
    if normalized.is_empty() {
        return Err(ApiError::BadRequest(
            "storyStylePack cannot be empty when set".into(),
        ));
    }
    if !pack_directory_exists(&normalized) {
        return Err(ApiError::BadRequest(format!(
            "unknown story style pack: {value}"
        )));
    }
    Ok(normalized)
}

pub fn validate_art_style_pack_field_patch(
    patch: FieldPatch<String>,
) -> Result<FieldPatch<String>, ApiError> {
    match patch {
        FieldPatch::Absent => Ok(FieldPatch::Absent),
        FieldPatch::Set(None) => Ok(FieldPatch::Set(None)),
        FieldPatch::Set(Some(value)) => {
            Ok(FieldPatch::Set(Some(validate_art_style_pack_set(&value)?)))
        }
    }
}

pub fn validate_story_style_pack_field_patch(
    patch: FieldPatch<String>,
) -> Result<FieldPatch<String>, ApiError> {
    match patch {
        FieldPatch::Absent => Ok(FieldPatch::Absent),
        FieldPatch::Set(None) => Ok(FieldPatch::Set(None)),
        FieldPatch::Set(Some(value)) => {
            Ok(FieldPatch::Set(Some(validate_story_style_pack_set(&value)?)))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_art_prefixes_bare_key() {
        assert_eq!(
            normalize_art_style_pack_path("2D_chinese_guofeng"),
            "art_skills/2D_chinese_guofeng"
        );
    }

    #[test]
    fn normalize_story_prefixes_bare_key() {
        assert_eq!(
            normalize_story_style_pack_path("Sweet_romance_novel"),
            "story_skills/Sweet_romance_novel"
        );
    }
}
