//! 写入槽位 Markdown 与同步参考图。

use std::collections::HashSet;
use std::path::Path;

use base64::Engine;
use uuid::Uuid;

use crate::error::ApiError;

use super::super::types::{DirectorManualDataItem, DIRECTOR_SLOTS};

fn valid_slot_values() -> HashSet<&'static str> {
    DIRECTOR_SLOTS.iter().map(|s| s.value).collect()
}

pub(crate) fn write_slots(
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

        if item.data.len() as u64 > super::super::MAX_SLOT_BYTES {
            return Err(ApiError::BadRequest(format!(
                "director-manual: slot {} exceeds max size",
                item.value
            )));
        }

        let rel_path: std::path::PathBuf = match slot.sub_dir {
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

pub(crate) fn sync_images(main_path: &Path, images: &[String]) -> Result<(), ApiError> {
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

        if item.len() > super::super::MAX_BASE64_IMAGE_INPUT_CHARS {
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
        if bytes.len() as u64 > super::super::MAX_DECODED_IMAGE_BYTES {
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
