//! 资产模块共享工具函数与常量。

use base64::Engine as _;
use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

use super::models::WorkbenchOwnedAssetMetaRow;

// ── Constants ────────────────────────────────────────────────────────────────

pub(super) const ADV_LOCK_ASSET_IMAGE_NUMERIC: i64 = 884_422_005;
pub(super) const MAX_ASSET_LIST_LIMIT: i64 = 200;
pub(super) const MAX_UPLOAD_CLIP_BASE64_LEN: usize = 24_000_000;

// ── Utility functions ────────────────────────────────────────────────────────

pub(super) fn normalize_optional_trimmed_text(raw: Option<String>) -> Option<String> {
    raw.map(|s| s.trim().to_string()).filter(|s| !s.is_empty())
}

pub(super) fn merge_workbench_asset_metadata(
    mut metadata: Value,
    prompt_patch: Option<Option<String>>,
    remark_patch: Option<Option<String>>,
    image_id_patch: Option<Option<i32>>,
) -> Value {
    if !metadata.is_object() {
        metadata = Value::Object(Default::default());
    }
    let Some(obj) = metadata.as_object_mut() else {
        return metadata;
    };

    if let Some(next_prompt) = prompt_patch {
        match next_prompt {
            Some(v) => {
                obj.insert("prompt".into(), Value::String(v));
            }
            None => {
                obj.remove("prompt");
            }
        }
    }

    if let Some(next_remark) = remark_patch {
        match next_remark {
            Some(v) => {
                obj.insert("remark".into(), Value::String(v));
            }
            None => {
                obj.remove("remark");
            }
        }
    }

    if let Some(next_image_id) = image_id_patch {
        match next_image_id {
            Some(v) => {
                obj.insert("imageId".into(), Value::from(v));
            }
            None => {
                obj.remove("imageId");
            }
        }
    }

    metadata
}

pub(super) fn metadata_cover_numeric_image_id(metadata: &Value) -> Option<i32> {
    let v = metadata.get("imageId")?;
    if v.is_null() {
        return None;
    }
    if let Some(n) = v.as_i64() {
        return i32::try_from(n).ok();
    }
    if let Some(n) = v.as_u64() {
        return i32::try_from(n).ok();
    }
    v.as_str().and_then(|s| s.trim().parse::<i32>().ok())
}

pub(super) fn normalize_list_asset_type_filter(
    raw: Option<String>,
) -> Result<Option<String>, ApiError> {
    let Some(s) = raw else {
        return Ok(None);
    };
    let t = s.trim().to_lowercase();
    if t.is_empty() {
        return Ok(None);
    }
    if t != "role" && t != "tool" && t != "scene" {
        return Err(ApiError::BadRequest(
            "asset_type must be role, tool, or scene".into(),
        ));
    }
    Ok(Some(t))
}

pub(super) fn normalize_name_ilike(raw: Option<String>) -> Option<String> {
    raw.and_then(|s| {
        let t = s.trim();
        if t.is_empty() {
            None
        } else {
            Some(format!("%{t}%"))
        }
    })
}

pub(super) fn normalize_corner_types_filter(
    raw: Option<Vec<String>>,
) -> Result<Option<Vec<String>>, ApiError> {
    let Some(list) = raw else {
        return Ok(None);
    };
    if list.is_empty() {
        return Ok(None);
    }
    let mut out = Vec::new();
    for s in list {
        let t = s.trim().to_lowercase();
        if t.is_empty() {
            continue;
        }
        if t != "role" && t != "scene" && t != "tool" {
            return Err(ApiError::BadRequest(format!(
                "types entries must be role, scene, or tool (got {s:?})"
            )));
        }
        if !out.iter().any(|v| v == &t) {
            out.push(t);
        }
    }
    if out.is_empty() {
        Ok(None)
    } else {
        Ok(Some(out))
    }
}

pub(super) fn normalize_upload_clip_data_uri(raw: &str) -> Result<String, ApiError> {
    let input = raw.trim();
    if input.is_empty() {
        return Err(ApiError::BadRequest("base64Data must not be empty".into()));
    }

    let (prefix, payload) = if let Some(rest) = input.strip_prefix("data:") {
        let comma_idx = rest
            .find(',')
            .ok_or_else(|| ApiError::BadRequest("base64Data must be a valid data URI".into()))?;
        let data_uri_prefix = &input[..(5 + comma_idx)];
        if !data_uri_prefix.to_ascii_lowercase().contains(";base64") {
            return Err(ApiError::BadRequest(
                "base64Data data URI must include ;base64".into(),
            ));
        }
        (Some(data_uri_prefix), &rest[(comma_idx + 1)..])
    } else {
        (None, input)
    };

    if payload.is_empty() {
        return Err(ApiError::BadRequest(
            "base64Data payload must not be empty".into(),
        ));
    }
    if payload.len() > MAX_UPLOAD_CLIP_BASE64_LEN {
        return Err(ApiError::BadRequest(format!(
            "base64Data exceeds max length {}",
            MAX_UPLOAD_CLIP_BASE64_LEN
        )));
    }
    let decoded = base64::engine::general_purpose::STANDARD
        .decode(payload)
        .map_err(|_| ApiError::BadRequest("base64Data must be valid base64".into()))?;
    if decoded.is_empty() {
        return Err(ApiError::BadRequest(
            "base64Data payload must not be empty".into(),
        ));
    }

    Ok(match prefix {
        Some(prefix) => format!("{prefix},{payload}"),
        None => format!("data:application/octet-stream;base64,{payload}"),
    })
}

pub(super) async fn resolve_owned_asset_metadata(
    pool: &PgPool,
    uid: Uuid,
    asset_numeric_id: i32,
) -> Result<WorkbenchOwnedAssetMetaRow, ApiError> {
    let row: Option<WorkbenchOwnedAssetMetaRow> = sqlx::query_as(
        r#"
        SELECT a.id, a.metadata
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND a.numeric_id = $2
        "#,
    )
    .bind(uid)
    .bind(asset_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    row.ok_or(ApiError::NotFound)
}
