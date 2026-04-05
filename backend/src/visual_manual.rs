//! Parity with legacy **`POST /api/project/getVisualManual`**: read bundled **`art_skills`** tree (Markdown + image paths).
//! **`image`** entries are **relative paths** under **`data/skills`** (no OSS signing). Clients load bytes via
//! **`GET /api/v1/skills/binary?path=`** with the same relative path (JWT required).

use std::path::{Path, PathBuf};

use axum::{extract::State, http::HeaderMap, routing::get, Json, Router};
use serde::Serialize;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::skills::skills_root;
use crate::state::AppState;

const MAX_SLOT_BYTES: u64 = 2_000_000;
const MAX_README_BYTES: u64 = 256_000;

#[derive(Debug, Clone, Copy)]
struct ManualSlotDef {
    label: &'static str,
    value: &'static str,
    /// Subdirectory under each style folder, or **`None`** for root-level **`{value}.md`**.
    sub_dir: Option<&'static str>,
}

const MANUAL_SLOTS: [ManualSlotDef; 12] = [
    ManualSlotDef {
        label: "README",
        value: "README",
        sub_dir: None,
    },
    ManualSlotDef {
        label: "前缀",
        value: "prefix",
        sub_dir: None,
    },
    ManualSlotDef {
        label: "角色",
        value: "art_character",
        sub_dir: Some("art_prompt"),
    },
    ManualSlotDef {
        label: "角色衍生",
        value: "art_character_derivative",
        sub_dir: Some("art_prompt"),
    },
    ManualSlotDef {
        label: "道具",
        value: "art_prop",
        sub_dir: Some("art_prompt"),
    },
    ManualSlotDef {
        label: "道具衍生",
        value: "art_prop_derivative",
        sub_dir: Some("art_prompt"),
    },
    ManualSlotDef {
        label: "场景",
        value: "art_scene",
        sub_dir: Some("art_prompt"),
    },
    ManualSlotDef {
        label: "场景衍生",
        value: "art_scene_derivative",
        sub_dir: Some("art_prompt"),
    },
    ManualSlotDef {
        label: "分镜",
        value: "director_storyboard",
        sub_dir: Some("driector_skills"),
    },
    ManualSlotDef {
        label: "分镜视频",
        value: "art_storyboard_video",
        sub_dir: Some("art_prompt"),
    },
    ManualSlotDef {
        label: "技法-导演规划",
        value: "director_planning_style",
        sub_dir: Some("driector_skills"),
    },
    ManualSlotDef {
        label: "技法-分镜表设计",
        value: "director_storyboard_table_style",
        sub_dir: Some("driector_skills"),
    },
];

#[derive(Debug, Serialize)]
pub struct VisualManualEntry {
    pub label: String,
    pub value: String,
    pub data: String,
}

#[derive(Debug, Serialize)]
pub struct VisualManualStyle {
    /// First line of **`README.md`** (legacy strips **`--`**).
    pub name: String,
    /// Relative paths under **`data/skills`**, e.g. **`art_skills/{style}/images/a.png`**.
    pub image: Vec<String>,
    #[serde(rename = "stylePath")]
    pub style_path: String,
    /// Same shape as legacy **`data`** array.
    pub data: Vec<VisualManualEntry>,
}

#[derive(Debug, Serialize)]
pub struct VisualManualResponse {
    pub styles: Vec<VisualManualStyle>,
}

pub fn router() -> Router<AppState> {
    Router::new().route("/api/v1/visual-manual", get(get_visual_manual))
}

fn is_safe_style_component(name: &str) -> bool {
    !name.is_empty()
        && name != "."
        && name != ".."
        && !name.contains('/')
        && !name.contains('\\')
        && !name.contains('\0')
}

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

fn load_visual_manual() -> Result<VisualManualResponse, ApiError> {
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

async fn get_visual_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<VisualManualResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    Ok(Json(load_visual_manual()?))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn load_visual_manual_smoke() {
        let r = load_visual_manual().expect("bundle");
        assert!(
            r.styles.len() >= 2,
            "expected multiple art styles, got {}",
            r.styles.len()
        );
        let anime = r
            .styles
            .iter()
            .find(|s| s.style_path == "2D_90s_japanese_anime")
            .expect("2D_90s_japanese_anime");
        assert!(!anime.name.is_empty());
        let scene = anime
            .data
            .iter()
            .find(|e| e.value == "art_scene")
            .expect("art_scene slot");
        assert!(
            scene.data.len() > 40,
            "expected art_scene md body, len {}",
            scene.data.len()
        );
    }
}
