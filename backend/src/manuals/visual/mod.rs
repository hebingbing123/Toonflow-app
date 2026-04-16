//! 视觉手册模块。
//!
//! 与遗留 `/api/project/getVisualManual` 和 `addVisualManual` / `editVisualManual` / `deleteVisualManual` 兼容：
//! 读/写打包的 `art_skills`（Markdown + 图片）。`GET` / `POST /api/v1/visual-manual` 列出样式；变更 `POST /api/v1/project/*-visual-manual`。
//! `image` 条目是相对于 `data/skills` 的路径（无 OSS 签名）。客户端通过 `GET /api/v1/skills/binary?path=` 加载字节（需要 JWT）。

use std::collections::HashSet;
use std::path::{Path, PathBuf};

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    routing::{get, post},
    Json as JsonResponse, Router,
};
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
const NAME_RULE_MSG: &str = "名称不能包含路径分隔符或为纯数字";

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
    /// First line of **`README.md`** (Electron client strips **`--`**).
    pub name: String,
    /// Relative paths under **`data/skills`**, e.g. **`art_skills/{style}/images/a.png`**.
    pub image: Vec<String>,
    #[serde(rename = "stylePath")]
    pub style_path: String,
    /// Same shape as Electron-era **`data`** array.
    pub data: Vec<VisualManualEntry>,
}

#[derive(Debug, Serialize)]
pub struct VisualManualResponse {
    pub styles: Vec<VisualManualStyle>,
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/visual-manual",
            get(get_visual_manual).post(post_visual_manual),
        )
        .route(
            "/api/v1/project/add-visual-manual",
            post(post_add_visual_manual),
        )
        .route(
            "/api/v1/project/edit-visual-manual",
            post(post_edit_visual_manual),
        )
        .route(
            "/api/v1/project/delete-visual-manual",
            post(post_delete_visual_manual),
        )
}

fn is_safe_style_component(name: &str) -> bool {
    !name.is_empty()
        && name != "."
        && name != ".."
        && !name.contains('/')
        && !name.contains('\\')
        && !name.contains('\0')
}

fn validate_manual_folder_name(key: &str) -> Result<(), ApiError> {
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

fn art_skills_style_dir(style_path: &str) -> Result<PathBuf, ApiError> {
    validate_manual_folder_name(style_path)?;
    let root = skills_root();
    if !root.is_dir() {
        return Err(ApiError::BadRequest(
            "skills directory missing (expected backend/data/skills)".into(),
        ));
    }
    Ok(root.join("art_skills").join(style_path))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct VisualManualDataItem {
    #[allow(dead_code)]
    label: String,
    value: String,
    data: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct AddVisualManualBody {
    name: String,
    images: Vec<String>,
    style_path: String,
    data: Vec<VisualManualDataItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct EditVisualManualBody {
    name: String,
    style_path: String,
    images: Vec<String>,
    data: Vec<VisualManualDataItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct DeleteVisualManualBody {
    name: String,
}

#[derive(Debug, Serialize)]
struct EmptyOkObject {}

#[derive(Debug, Serialize)]
struct DeleteVisualManualResponse {
    message: &'static str,
}

fn valid_visual_slot_values() -> HashSet<&'static str> {
    MANUAL_SLOTS.iter().map(|s| s.value).collect()
}

fn write_visual_slots(
    main_path: &Path,
    display_name: &str,
    items: &[VisualManualDataItem],
    readme_prefix_display_name: bool,
) -> Result<(), ApiError> {
    let valid = valid_visual_slot_values();
    for item in items {
        if !valid.contains(item.value.as_str()) {
            continue;
        }
        let slot = MANUAL_SLOTS
            .iter()
            .find(|s| s.value == item.value.as_str())
            .expect("value in set matches slot");
        if item.data.len() as u64 > MAX_SLOT_BYTES {
            return Err(ApiError::BadRequest(format!(
                "visual-manual: slot {} exceeds max size",
                item.value
            )));
        }
        let rel_path: PathBuf = match slot.sub_dir {
            Some(sub) => main_path.join(sub).join(format!("{}.md", slot.value)),
            None => main_path.join(format!("{}.md", slot.value)),
        };
        if let Some(parent) = rel_path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| {
                ApiError::BadRequest(format!("visual-manual: mkdir {}: {e}", parent.display()))
            })?;
        }
        let content = if readme_prefix_display_name && item.value == "README" {
            format!("{display_name}\n{}", item.data)
        } else {
            item.data.clone()
        };
        std::fs::write(&rel_path, content).map_err(|e| {
            ApiError::BadRequest(format!("visual-manual: write {}: {e}", rel_path.display()))
        })?;
    }
    Ok(())
}

fn sync_visual_images(main_path: &Path, images: &[String]) -> Result<(), ApiError> {
    let images_dir = main_path.join("images");
    let mut existing: Vec<String> = Vec::new();
    if images_dir.is_dir() {
        for e in std::fs::read_dir(&images_dir)
            .map_err(|e| ApiError::BadRequest(format!("visual-manual: readdir images: {e}")))?
        {
            let e =
                e.map_err(|e| ApiError::BadRequest(format!("visual-manual: images entry: {e}")))?;
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

    let mut retained = HashSet::new();
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
        .map_err(|e| ApiError::BadRequest(format!("visual-manual: mkdir images: {e}")))?;

    for item in images {
        if item.starts_with("http://") || item.starts_with("https://") {
            continue;
        }
        if item.len() > MAX_BASE64_IMAGE_INPUT_CHARS {
            return Err(ApiError::BadRequest(
                "visual-manual: base64 image payload too large".into(),
            ));
        }
        let b64 = item
            .strip_prefix("data:")
            .and_then(|s| s.split_once(";base64,"))
            .map(|(_, b)| b)
            .unwrap_or(item);
        let bytes = base64::engine::general_purpose::STANDARD
            .decode(b64.trim().as_bytes())
            .map_err(|_| ApiError::BadRequest("visual-manual: invalid base64 image".into()))?;
        if bytes.len() as u64 > MAX_DECODED_IMAGE_BYTES {
            return Err(ApiError::BadRequest(
                "visual-manual: decoded image too large".into(),
            ));
        }
        let file_name = format!("{}.jpg", Uuid::new_v4());
        let target = images_dir.join(&file_name);
        std::fs::write(&target, bytes)
            .map_err(|e| ApiError::BadRequest(format!("visual-manual: write image: {e}")))?;
    }

    Ok(())
}

async fn post_add_visual_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AddVisualManualBody>,
) -> Result<JsonResponse<EmptyOkObject>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    validate_manual_folder_name(&body.name)?;
    validate_manual_folder_name(&body.style_path)?;

    let main_path = art_skills_style_dir(&body.style_path)?;
    if main_path.exists() {
        return Err(ApiError::BadRequest("请勿填写重复名称的视觉手册".into()));
    }

    std::fs::create_dir_all(&main_path).map_err(|e| {
        ApiError::BadRequest(format!(
            "visual-manual: create {}: {e}",
            main_path.display()
        ))
    })?;

    if let Err(e) = write_visual_slots(&main_path, &body.name, &body.data, false) {
        let _ = std::fs::remove_dir_all(&main_path);
        return Err(e);
    }
    if let Err(e) = sync_visual_images(&main_path, &body.images) {
        let _ = std::fs::remove_dir_all(&main_path);
        return Err(e);
    }

    Ok(JsonResponse(EmptyOkObject {}))
}

async fn post_edit_visual_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<EditVisualManualBody>,
) -> Result<JsonResponse<EmptyOkObject>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    validate_manual_folder_name(&body.name)?;
    validate_manual_folder_name(&body.style_path)?;

    let main_path = art_skills_style_dir(&body.style_path)?;
    if !main_path.is_dir() {
        return Err(ApiError::BadRequest("视觉手册不存在".into()));
    }

    write_visual_slots(&main_path, &body.name, &body.data, true)?;
    sync_visual_images(&main_path, &body.images)?;

    Ok(JsonResponse(EmptyOkObject {}))
}

async fn post_delete_visual_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteVisualManualBody>,
) -> Result<JsonResponse<DeleteVisualManualResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    validate_manual_folder_name(&body.name)?;
    if let Ok(dir) = art_skills_style_dir(&body.name) {
        if dir.is_dir() {
            let _ = std::fs::remove_dir_all(&dir);
        }
    }
    Ok(JsonResponse(DeleteVisualManualResponse {
        message: "删除成功",
    }))
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
) -> Result<JsonResponse<VisualManualResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    Ok(JsonResponse(load_visual_manual()?))
}

/// Same payload as [`get_visual_manual`]; **POST** matches Electron-era **`POST /api/project/getVisualManual`** (body ignored).
async fn post_visual_manual(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<JsonResponse<VisualManualResponse>, ApiError> {
    get_visual_manual(State(state), headers).await
}

#[cfg(test)]
mod tests;
