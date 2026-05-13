//! 扫描 `story_skills` 并构建导演手册列表响应。

use std::path::{Path, PathBuf};

use crate::error::{bad_request_i18n, ApiError};
use crate::prompting::skills::skills_root;

use super::super::types::{
    DirectorManualListResponse, DirectorManualSlotRow, DirectorManualStyleRow, DIRECTOR_SLOTS,
};
use super::paths::is_safe_style_component;

fn read_limited_utf8(path: &Path, max_bytes: u64) -> Result<String, ApiError> {
    let meta = std::fs::metadata(path).map_err(|e| {
        bad_request_i18n(
            &format!("director-manual: cannot stat {}: {e}", path.display()),
            &format!("director-manual：无法读取 {} 的元数据：{e}", path.display()),
        )
    })?;
    if meta.len() > max_bytes {
        return Err(bad_request_i18n(
            &format!("director-manual: file too large: {}", path.display()),
            &format!("director-manual：文件过大：{}", path.display()),
        ));
    }
    std::fs::read_to_string(path).map_err(|e| {
        bad_request_i18n(
            &format!("director-manual: cannot read {}: {e}", path.display()),
            &format!("director-manual：无法读取 {}：{e}", path.display()),
        )
    })
}

fn read_md_or_empty(path: &Path) -> String {
    if !path.is_file() {
        return String::new();
    }
    read_limited_utf8(path, super::super::MAX_SLOT_BYTES).unwrap_or_else(|_| String::new())
}

fn readme_display_name(style_dir: &Path, style_key: &str) -> String {
    let readme = style_dir.join("README.md");
    if !readme.is_file() {
        return style_key.to_string();
    }
    match read_limited_utf8(&readme, super::super::MAX_README_BYTES) {
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

fn image_relative_paths_story(style_key: &str, images_dir: &Path) -> Vec<String> {
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
        .map(|f| format!("story_skills/{style_key}/images/{f}"))
        .collect()
}

fn build_row(style_key: &str, style_dir: &Path) -> DirectorManualStyleRow {
    let name = readme_display_name(style_dir, style_key);
    let images_dir = style_dir.join("images");
    let image = image_relative_paths_story(style_key, &images_dir);

    let mut data = Vec::with_capacity(DIRECTOR_SLOTS.len());
    for slot in &DIRECTOR_SLOTS {
        let path: PathBuf = match slot.sub_dir {
            Some(sub) => style_dir.join(sub).join(format!("{}.md", slot.value)),
            None => style_dir.join(format!("{}.md", slot.value)),
        };
        let body = read_md_or_empty(&path);
        data.push(DirectorManualSlotRow {
            label: slot.label.to_string(),
            value: slot.value.to_string(),
            data: body,
        });
    }

    DirectorManualStyleRow {
        name,
        image,
        director_manual_key: style_key.to_string(),
        data,
    }
}

pub(crate) fn load_director_manual_list() -> Result<DirectorManualListResponse, ApiError> {
    let root = skills_root();
    let story = root.join("story_skills");
    if !story.is_dir() {
        return Err(bad_request_i18n(
            "story_skills directory missing (expected backend/data/skills/story_skills)",
            "story_skills 目录缺失（预期为 backend/data/skills/story_skills）",
        ));
    }

    let mut keys: Vec<String> = Vec::new();
    for entry in std::fs::read_dir(&story).map_err(|e| {
        bad_request_i18n(
            &format!("director-manual: cannot read story_skills: {e}"),
            &format!("director-manual：无法读取 story_skills：{e}"),
        )
    })? {
        let entry = entry.map_err(|e| {
            bad_request_i18n(
                &format!("director-manual: story_skills entry: {e}"),
                &format!("director-manual：读取 story_skills 条目失败：{e}"),
            )
        })?;
        let ft = entry.file_type().map_err(|e| {
            bad_request_i18n(
                &format!("director-manual: file_type: {e}"),
                &format!("director-manual：读取 file_type 失败：{e}"),
            )
        })?;
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

    let mut data = Vec::with_capacity(keys.len());
    for key in keys {
        let style_dir = story.join(&key);
        data.push(build_row(&key, &style_dir));
    }

    Ok(DirectorManualListResponse { data })
}
