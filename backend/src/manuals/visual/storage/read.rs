use std::path::{Path, PathBuf};

use crate::error::ApiError;
use crate::prompting::skills::skills_root;

use super::super::slots::{MANUAL_SLOTS, MAX_README_BYTES, MAX_SLOT_BYTES};
use super::super::types::{VisualManualEntry, VisualManualResponse, VisualManualStyle};
use super::super::validation::is_safe_style_component;

fn read_limited_utf8(path: &Path, max_bytes: u64) -> Result<String, ApiError> {
    let meta = std::fs::metadata(path).map_err(|e| {
        ApiError::BadRequest(format!(
            "visual-manual: cannot stat {}: {e}",
            path.display()
        ))
    })?;
    if meta.len() > max_bytes {
        return Err(ApiError::BadRequest(format!(
            "visual-manual: file too large: {}",
            path.display()
        )));
    }
    std::fs::read_to_string(path).map_err(|e| {
        ApiError::BadRequest(format!(
            "visual-manual: cannot read {}: {e}",
            path.display()
        ))
    })
}

fn read_md_or_empty(path: &Path) -> String {
    if !path.is_file() {
        return String::new();
    }
    read_limited_utf8(path, MAX_SLOT_BYTES).unwrap_or_else(|_| String::new())
}

fn readme_display_name(style_dir: &Path, style_key: &str) -> String {
    let readme = style_dir.join("README.md");
    if !readme.is_file() {
        return style_key.to_string();
    }
    match read_limited_utf8(&readme, MAX_README_BYTES) {
        Ok(content) => content
            .lines()
            .next()
            .unwrap_or("")
            .replace("--", "")
            .trim()
            .to_string(),
        Err(_) => style_key.to_string(),
    }
}

fn image_relative_paths(style_key: &str, images_dir: &Path) -> Vec<String> {
    let Ok(entries) = std::fs::read_dir(images_dir) else {
        return Vec::new();
    };
    let mut names: Vec<String> = entries
        .filter_map(|e| e.ok())
        .filter(|e| e.path().is_file())
        .filter_map(|e| e.file_name().into_string().ok())
        .filter(|n| {
            let lower = n.to_ascii_lowercase();
            lower.ends_with(".png")
                || lower.ends_with(".jpg")
                || lower.ends_with(".jpeg")
                || lower.ends_with(".gif")
                || lower.ends_with(".webp")
                || lower.ends_with(".svg")
        })
        .collect();
    names.sort();
    names
        .into_iter()
        .map(|f| format!("art_skills/{style_key}/images/{f}"))
        .collect()
}

fn build_style(style_key: &str, style_dir: &Path) -> VisualManualStyle {
    let name = readme_display_name(style_dir, style_key);
    let images_dir = style_dir.join("images");
    let image = image_relative_paths(style_key, &images_dir);

    let mut data = Vec::with_capacity(MANUAL_SLOTS.len());
    for slot in &MANUAL_SLOTS {
        let path: PathBuf = match slot.sub_dir {
            Some(sub) => style_dir.join(sub).join(format!("{}.md", slot.value)),
            None => style_dir.join(format!("{}.md", slot.value)),
        };
        let body = read_md_or_empty(&path);
        data.push(VisualManualEntry {
            label: slot.label.to_string(),
            value: slot.value.to_string(),
            data: body,
        });
    }

    VisualManualStyle {
        name,
        image,
        style_path: style_key.to_string(),
        data,
    }
}

pub(crate) fn load_visual_manual() -> Result<VisualManualResponse, ApiError> {
    let root = skills_root();
    let art = root.join("art_skills");
    if !art.is_dir() {
        return Err(ApiError::BadRequest(
            "art_skills directory missing (expected backend/data/skills/art_skills)".into(),
        ));
    }

    let mut keys: Vec<String> = Vec::new();
    for entry in std::fs::read_dir(&art)
        .map_err(|e| ApiError::BadRequest(format!("visual-manual: cannot read art_skills: {e}")))?
    {
        let entry = entry
            .map_err(|e| ApiError::BadRequest(format!("visual-manual: art_skills entry: {e}")))?;
        let ft = entry
            .file_type()
            .map_err(|e| ApiError::BadRequest(format!("visual-manual: file_type: {e}")))?;
        if !ft.is_dir() {
            continue;
        }
        let name = entry.file_name().to_string_lossy().to_string();
        if !is_safe_style_component(&name) {
            continue;
        }
        keys.push(name);
    }
    keys.sort();

    let mut styles = Vec::with_capacity(keys.len());
    for key in keys {
        let style_dir = art.join(&key);
        styles.push(build_style(&key, &style_dir));
    }

    Ok(VisualManualResponse { styles })
}
