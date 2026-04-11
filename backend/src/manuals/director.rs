//! 导演手册模块。
//!
//! 与遗留 `/api/project/queryDirectorManual`、`addDirectorManual`、`editDirectorlManual`、`deleteDirectorManual` 兼容：
//! 打包的 `story_skills` 树（Markdown + 图片）。图片路径是相对于 `data/skills` 的（与视觉手册相同；客户端通过 `GET /api/v1/skills/binary?path=` 获取）。

use std::path::{Path, PathBuf};

use axum::{extract::State, http::HeaderMap, routing::post, Json, Router};
use base64::Engine;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::prompting::skills::skills_root;
use crate::state::AppState;

const MAX_SLOT_BYTES: u64 = 2_000_000;
const MAX_README_BYTES: u64 = 256_000;
const MAX_BASE64_IMAGE_INPUT_CHARS: usize = 45_000_000;
const MAX_DECODED_IMAGE_BYTES: u64 = 25_000_000;

#[derive(Debug, Clone, Copy)]
struct DirectorSlotDef {
    label: &'static str,
    value: &'static str,
    sub_dir: Option<&'static str>,
}

/// Same three slots as Electron-era **`addDirectorManual`** / **`queryDirectorManual`** (**`driector_skills`** spelling preserved).
const DIRECTOR_SLOTS: [DirectorSlotDef; 3] = [
    DirectorSlotDef {
        label: "README",
        value: "README",
        sub_dir: None,
    },
    DirectorSlotDef {
        label: "导演规划",
        value: "director_planning_narrative",
        sub_dir: Some("driector_skills"),
    },
    DirectorSlotDef {
        label: "分镜表",
        value: "director_storyboard_table_narrative",
        sub_dir: Some("driector_skills"),
    },
];

#[derive(Debug, Serialize)]
pub struct DirectorManualSlotRow {
    pub label: String,
    pub value: String,
    pub data: String,
}

#[derive(Debug, Serialize)]
pub struct DirectorManualStyleRow {
    pub name: String,
    pub image: Vec<String>,
    /// Folder name under **`story_skills/`** (SQLite field **`directorManual`**).
    #[serde(rename = "directorManual")]
    pub director_manual_key: String,
    pub data: Vec<DirectorManualSlotRow>,
}

#[derive(Debug, Serialize)]
pub struct DirectorManualListResponse {
    pub data: Vec<DirectorManualStyleRow>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct DirectorManualDataItem {
    #[allow(dead_code)]
    label: String,
    value: String,
    data: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct AddDirectorManualBody {
    /// Display title used when writing **`README`** on **add** (Electron client did not prefix on add).
    name: String,
    images: Vec<String>,
    /// Target subdirectory under **`story_skills/`**.
    director_manual: String,
    data: Vec<DirectorManualDataItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct EditDirectorManualBody {
    name: String,
    director_manual: String,
    images: Vec<String>,
    data: Vec<DirectorManualDataItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct DeleteDirectorManualBody {
    /// Folder name under **`story_skills/`** (Electron-era **`name`**).
    name: String,
}

#[derive(Debug, Serialize)]
struct EmptyOkResponse {}

#[derive(Debug, Serialize)]
struct DeleteDirectorManualResponse {
    message: &'static str,
}

fn is_safe_style_component(name: &str) -> bool {
    !name.is_empty()
        && name != "."
        && name != ".."
        && !name.contains('/')
        && !name.contains('\\')
        && !name.contains('\0')
        && !name.chars().all(|c| c.is_ascii_digit())
}

fn validate_style_key(msg_zh: &'static str, key: &str) -> Result<(), ApiError> {
    if is_safe_style_component(key) {
        Ok(())
    } else {
        Err(ApiError::BadRequest(msg_zh.into()))
    }
}

fn read_limited_utf8(path: &Path, max_bytes: u64) -> Result<String, ApiError> {
    let meta = std::fs::metadata(path).map_err(|e| {
        ApiError::BadRequest(format!(
            "director-manual: cannot stat {}: {e}",
            path.display()
        ))
    })?;
    if meta.len() > max_bytes {
        return Err(ApiError::BadRequest(format!(
            "director-manual: file too large: {}",
            path.display()
        )));
    }
    std::fs::read_to_string(path).map_err(|e| {
        ApiError::BadRequest(format!(
            "director-manual: cannot read {}: {e}",
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

fn valid_slot_values() -> std::collections::HashSet<&'static str> {
    DIRECTOR_SLOTS.iter().map(|s| s.value).collect()
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

fn load_director_manual_list() -> Result<DirectorManualListResponse, ApiError> {
    let root = skills_root();
    let story = root.join("story_skills");
    if !story.is_dir() {
        return Err(ApiError::BadRequest(
            "story_skills directory missing (expected backend/data/skills/story_skills)".into(),
        ));
    }

    let mut keys: Vec<String> = Vec::new();
    for entry in std::fs::read_dir(&story).map_err(|e| {
        ApiError::BadRequest(format!("director-manual: cannot read story_skills: {e}"))
    })? {
        let entry = entry.map_err(|e| {
            ApiError::BadRequest(format!("director-manual: story_skills entry: {e}"))
        })?;
        let ft = entry
            .file_type()
            .map_err(|e| ApiError::BadRequest(format!("director-manual: file_type: {e}")))?;
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

async fn post_query_director_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<DirectorManualListResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    Ok(Json(load_director_manual_list()?))
}

fn story_manual_dir(director_manual: &str) -> Result<PathBuf, ApiError> {
    validate_style_key("名称不能包含路径分隔符或为纯数字", director_manual)?;
    let root = skills_root();
    if !root.is_dir() {
        return Err(ApiError::BadRequest(
            "skills directory missing (expected backend/data/skills)".into(),
        ));
    }
    Ok(root.join("story_skills").join(director_manual))
}

fn write_slots(
    main_path: &Path,
    display_name: &str,
    items: &[DirectorManualDataItem],
    readme_prefix_name: bool,
) -> Result<(), ApiError> {
    let valid = valid_slot_values();
    for item in items {
        if !valid.contains(item.value.as_str()) {
            continue;
        }
        let slot = DIRECTOR_SLOTS
            .iter()
            .find(|s| s.value == item.value)
            .expect("value in set matches slot");
        if item.data.len() as u64 > MAX_SLOT_BYTES {
            return Err(ApiError::BadRequest(format!(
                "director-manual: slot {} exceeds max size",
                item.value
            )));
        }
        let rel_path: PathBuf = match slot.sub_dir {
            Some(sub) => main_path.join(sub).join(format!("{}.md", slot.value)),
            None => main_path.join(format!("{}.md", slot.value)),
        };
        if let Some(parent) = rel_path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| {
                ApiError::BadRequest(format!("director-manual: mkdir {}: {e}", parent.display()))
            })?;
        }
        let content = if readme_prefix_name && item.value == "README" {
            format!("{display_name}\n{}", item.data)
        } else {
            item.data.clone()
        };
        std::fs::write(&rel_path, content).map_err(|e| {
            ApiError::BadRequest(format!(
                "director-manual: write {}: {e}",
                rel_path.display()
            ))
        })?;
    }
    Ok(())
}

fn sync_images(main_path: &Path, images: &[String]) -> Result<(), ApiError> {
    let images_dir = main_path.join("images");
    let mut existing: Vec<String> = Vec::new();
    if images_dir.is_dir() {
        for e in std::fs::read_dir(&images_dir)
            .map_err(|e| ApiError::BadRequest(format!("director-manual: readdir images: {e}")))?
        {
            let e =
                e.map_err(|e| ApiError::BadRequest(format!("director-manual: images entry: {e}")))?;
            let n = e.file_name().to_string_lossy().to_string();
            let lower = n.to_ascii_lowercase();
            if lower.ends_with(".png")
                || lower.ends_with(".jpg")
                || lower.ends_with(".jpeg")
                || lower.ends_with(".gif")
                || lower.ends_with(".webp")
                || lower.ends_with(".svg")
            {
                existing.push(n);
            }
        }
    }

    let mut retained = std::collections::HashSet::new();
    for item in images {
        if let Some(rest) = item
            .strip_prefix("http://")
            .or_else(|| item.strip_prefix("https://"))
        {
            if let Some(idx) = rest.find('/') {
                let path = &rest[idx..];
                let path = path.split('?').next().unwrap_or(path);
                if let Some(seg) = path.rsplit('/').next() {
                    if !seg.is_empty() {
                        retained.insert(seg.to_string());
                    }
                }
            }
        }
    }

    for file in &existing {
        if !retained.contains(file) {
            let p = images_dir.join(file);
            let _ = std::fs::remove_file(p);
        }
    }

    std::fs::create_dir_all(&images_dir)
        .map_err(|e| ApiError::BadRequest(format!("director-manual: mkdir images: {e}")))?;

    for item in images {
        if item.starts_with("http://") || item.starts_with("https://") {
            continue;
        }
        if item.len() > MAX_BASE64_IMAGE_INPUT_CHARS {
            return Err(ApiError::BadRequest(
                "director-manual: base64 image payload too large".into(),
            ));
        }
        let b64 = item
            .strip_prefix("data:")
            .and_then(|s| s.split_once(";base64,"))
            .map(|(_, b)| b)
            .unwrap_or(item);
        let bytes = base64::engine::general_purpose::STANDARD
            .decode(b64.trim().as_bytes())
            .map_err(|_| ApiError::BadRequest("director-manual: invalid base64 image".into()))?;
        if bytes.len() as u64 > MAX_DECODED_IMAGE_BYTES {
            return Err(ApiError::BadRequest(
                "director-manual: decoded image too large".into(),
            ));
        }
        let file_name = format!("{}.jpg", Uuid::new_v4());
        let target = images_dir.join(&file_name);
        std::fs::write(&target, bytes)
            .map_err(|e| ApiError::BadRequest(format!("director-manual: write image: {e}")))?;
    }

    Ok(())
}

async fn post_add_director_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AddDirectorManualBody>,
) -> Result<Json<EmptyOkResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    validate_style_key("名称不能包含路径分隔符或为纯数字", &body.name)?;
    validate_style_key("名称不能包含路径分隔符或为纯数字", &body.director_manual)?;

    let main_path = story_manual_dir(&body.director_manual)?;
    if main_path.exists() {
        return Err(ApiError::BadRequest("请勿填写重复名称的视觉手册".into()));
    }

    std::fs::create_dir_all(&main_path).map_err(|e| {
        ApiError::BadRequest(format!(
            "director-manual: create {}: {e}",
            main_path.display()
        ))
    })?;

    if let Err(e) = write_slots(&main_path, &body.name, &body.data, false) {
        let _ = std::fs::remove_dir_all(&main_path);
        return Err(e);
    }
    if let Err(e) = sync_images(&main_path, &body.images) {
        let _ = std::fs::remove_dir_all(&main_path);
        return Err(e);
    }

    Ok(Json(EmptyOkResponse {}))
}

async fn post_edit_director_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<EditDirectorManualBody>,
) -> Result<Json<EmptyOkResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    validate_style_key("名称不能包含路径分隔符或为纯数字", &body.name)?;
    validate_style_key("名称不能包含路径分隔符或为纯数字", &body.director_manual)?;

    let main_path = story_manual_dir(&body.director_manual)?;
    if !main_path.is_dir() {
        return Err(ApiError::BadRequest("导演手册不存在".into()));
    }

    write_slots(&main_path, &body.name, &body.data, true)?;
    sync_images(&main_path, &body.images)?;

    Ok(Json(EmptyOkResponse {}))
}

async fn post_delete_director_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteDirectorManualBody>,
) -> Result<Json<DeleteDirectorManualResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    validate_style_key("名称不能包含路径分隔符或为纯数字", &body.name)?;
    if let Ok(dir) = story_manual_dir(&body.name) {
        if dir.is_dir() {
            let _ = std::fs::remove_dir_all(&dir);
        }
    }
    Ok(Json(DeleteDirectorManualResponse {
        message: "删除成功",
    }))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/project/query-director-manual",
            post(post_query_director_manual),
        )
        .route(
            "/api/v1/project/add-director-manual",
            post(post_add_director_manual),
        )
        .route(
            "/api/v1/project/edit-director-manual",
            post(post_edit_director_manual),
        )
        .route(
            "/api/v1/project/delete-director-manual",
            post(post_delete_director_manual),
        )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn load_director_manual_smoke() {
        let r = load_director_manual_list().expect("bundle");
        assert!(
            r.data.len() >= 2,
            "expected multiple story_skills styles, got {}",
            r.data.len()
        );
        let family = r
            .data
            .iter()
            .find(|s| s.director_manual_key == "Family_warmth")
            .expect("Family_warmth");
        assert!(!family.name.is_empty());
        let planning = family
            .data
            .iter()
            .find(|e| e.value == "director_planning_narrative")
            .expect("planning slot");
        assert!(
            planning.data.len() > 20,
            "expected md body, len {}",
            planning.data.len()
        );
    }
}
