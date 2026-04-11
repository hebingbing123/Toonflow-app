//! 资产模块：项目范围的 `app_asset` HTTP API 和 `app_script_asset` 关联。
//!
//! 子模块：
//! - `models` — 请求/响应类型
//! - `legacy` — 遗留 POST 写入操作（添加/更新/保存/删除）
//! - `legacy_query` — 遗留 POST 读取/查询
//! - `crud` — REST CRUD 资产操作、角景、脚本-资产关联
//! - `crud_images` — 资产图片 REST CRUD
//! - `generate` — 遗留 `/api/assetsGenerate/*` 入队和取消

mod crud;
mod crud_images;
mod generate;
mod legacy;
mod legacy_query;
pub mod models;

pub use crud::{next_asset_image_sort_index, resolve_asset_id_for_job};

use axum::{
    routing::{get, post, put},
    Router,
};
use base64::Engine as _;
use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::state::AppState;
use models::LegacyOwnedAssetMetaRow;

// ── Module-level constants ───────────────────────────────────────────────────

pub(super) const ADV_LOCK_ASSET_LEGACY: i64 = 884_422_004;
pub(super) const ADV_LOCK_ASSET_IMAGE_LEGACY: i64 = 884_422_005;
pub(super) const MAX_ASSET_LIST_LIMIT: i64 = 200;
const MAX_UPLOAD_CLIP_BASE64_LEN: usize = 24_000_000;

// ── Shared utility functions ─────────────────────────────────────────────────

pub(super) fn normalize_optional_legacy_text(raw: Option<String>) -> Option<String> {
    raw.map(|s| s.trim().to_string()).filter(|s| !s.is_empty())
}

pub(super) fn merge_legacy_asset_metadata(
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

pub(super) fn metadata_cover_legacy_image_id(metadata: &Value) -> Option<i32> {
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
    asset_legacy_id: i32,
) -> Result<LegacyOwnedAssetMetaRow, ApiError> {
    let row: Option<LegacyOwnedAssetMetaRow> = sqlx::query_as(
        r#"
        SELECT a.id, a.metadata, p.legacy_id AS project_legacy_id
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND a.legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(asset_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    row.ok_or(ApiError::NotFound)
}

// ── Router ───────────────────────────────────────────────────────────────────

pub fn router() -> Router<AppState> {
    use crud::*;
    use crud_images::*;
    use legacy::*;
    use legacy_query::*;

    Router::new()
        .route("/api/v1/assets/add-assets", post(post_legacy_add_assets))
        .route("/api/v1/assets/save-assets", post(post_legacy_save_assets))
        .route(
            "/api/v1/assets/update-assets",
            post(post_legacy_update_assets),
        )
        .route("/api/v1/assets/del-assets", post(post_legacy_del_assets))
        .route(
            "/api/v1/assets/batch-delete",
            post(post_legacy_batch_delete_assets),
        )
        .route("/api/v1/assets/del-image", post(post_legacy_del_image))
        .route(
            "/api/v1/assets/get-assets-api",
            post(post_legacy_get_assets_api),
        )
        .route("/api/v1/assets/get-image", post(post_legacy_get_image))
        .route(
            "/api/v1/assets/upload-clip",
            post(post_legacy_upload_clip),
        )
        .route(
            "/api/v1/assets/get-material-data",
            post(post_legacy_get_material_data),
        )
        .route(
            "/api/v1/assets/batch-generation-data",
            post(post_legacy_batch_generation_data),
        )
        .route(
            "/api/v1/assets/polling-image-assets",
            post(post_legacy_polling_image_assets),
        )
        .route(
            "/api/v1/assets/polling-prompt-assets",
            post(post_legacy_polling_prompt_assets),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/assets",
            get(list_project_assets).post(create_project_asset),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/assets/corner-scape",
            post(list_corner_scape_assets),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images/{image_id}/file",
            get(get_project_asset_image_file),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images/{image_id}",
            get(get_project_asset_image)
                .patch(patch_project_asset_image)
                .delete(delete_project_asset_image),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images",
            get(list_project_asset_images).post(create_project_asset_image),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}",
            get(get_project_asset_by_legacy)
                .patch(patch_project_asset_by_legacy)
                .delete(delete_project_asset_by_legacy),
        )
        .route(
            "/api/v1/projects/legacy/{project_legacy_id}/scripts/{script_legacy_id}/assets/{asset_legacy_id}",
            put(link_script_to_asset).delete(unlink_script_from_asset),
        )
        .merge(generate::router())
}

// ── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::http_kit::json_patch::FieldPatch;
    use models::*;

    #[test]
    fn patch_asset_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<PatchAssetBody>(r#"{"name":"a","x":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn patch_asset_body_accepts_cover_legacy_image_id_only() {
        let b: PatchAssetBody = serde_json::from_str(r#"{"cover_legacy_image_id":42}"#).unwrap();
        assert!(b.name.is_none());
        assert_eq!(
            crate::http_kit::json_patch::parse_optional_i32_field(b.cover_legacy_image_id, "c")
                .unwrap(),
            FieldPatch::Set(Some(42))
        );
    }

    #[test]
    fn create_asset_body_accepts_minimal() {
        let b: CreateAssetBody = serde_json::from_str(r#"{"name":"Hero","type":"role"}"#).unwrap();
        assert_eq!(b.name, "Hero");
        assert_eq!(b.asset_type, "role");
    }

    #[test]
    fn create_asset_image_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<CreateAssetImageBody>(r#"{"x":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn create_asset_image_body_accepts_empty_object() {
        let b: CreateAssetImageBody = serde_json::from_str("{}").unwrap();
        assert!(b.file_path.is_none());
        assert!(b.state.is_none());
        assert!(b.sort_index.is_none());
    }

    #[test]
    fn patch_asset_image_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<PatchAssetImageBody>(r#"{"state":"x","x":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn upload_clip_base64_normalize_accepts_raw_payload() {
        let normalized = normalize_upload_clip_data_uri("AA==").unwrap();
        assert_eq!(normalized, "data:application/octet-stream;base64,AA==");
    }

    #[test]
    fn upload_clip_base64_normalize_accepts_data_uri_payload() {
        let normalized = normalize_upload_clip_data_uri("data:image/png;base64,AA==").unwrap();
        assert_eq!(normalized, "data:image/png;base64,AA==");
    }

    #[test]
    fn upload_clip_base64_normalize_rejects_non_base64_data_uri() {
        let err = normalize_upload_clip_data_uri("data:image/png,AA==").unwrap_err();
        match err {
            ApiError::BadRequest(msg) => assert!(msg.contains(";base64")),
            other => panic!("unexpected error: {other:?}"),
        }
    }

    #[test]
    fn upload_clip_base64_normalize_rejects_invalid_payload() {
        let err = normalize_upload_clip_data_uri("data:image/png;base64,not-base64").unwrap_err();
        match err {
            ApiError::BadRequest(msg) => assert!(msg.contains("valid base64")),
            other => panic!("unexpected error: {other:?}"),
        }
    }

    #[test]
    fn upload_clip_body_accepts_legacy_type_key() {
        let body: LegacyUploadClipBody = serde_json::from_str(
            r#"{"projectId":1,"base64Data":"AA==","type":"clip","name":"demo"}"#,
        )
        .unwrap();
        assert_eq!(body.project_id, 1);
        assert_eq!(body.asset_type.as_deref(), Some("clip"));
    }

    #[test]
    fn legacy_get_assets_api_body_accepts_minimal() {
        let body: LegacyGetAssetsApiBody =
            serde_json::from_str(r#"{"projectId":1,"type":"role"}"#).unwrap();
        assert_eq!(body.project_id, 1);
        assert_eq!(body.asset_type, "role");
        assert!(body.name.is_none());
        assert!(body.page.is_none());
        assert!(body.limit.is_none());
    }

    #[test]
    fn legacy_get_assets_api_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<LegacyGetAssetsApiBody>(
            r#"{"projectId":1,"type":"role","x":1}"#,
        )
        .unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn legacy_add_assets_body_accepts_minimal() {
        let body: LegacyAddAssetsBody = serde_json::from_str(
            r#"{"name":"Hero","describe":"Main role","type":"role","projectId":1}"#,
        )
        .unwrap();
        assert_eq!(body.name, "Hero");
        assert_eq!(body.project_id, 1);
        assert_eq!(body.asset_type, "role");
    }

    #[test]
    fn legacy_save_assets_body_accepts_image_id_without_base64() {
        let body: LegacySaveAssetsBody =
            serde_json::from_str(r#"{"id":1,"projectId":2,"type":"role","imageId":3}"#).unwrap();
        assert_eq!(body.id, 1);
        assert_eq!(body.project_id, 2);
        assert_eq!(body.image_id, Some(3));
    }

    #[test]
    fn legacy_batch_delete_assets_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<LegacyBatchDeleteAssetsBody>(r#"{"id":[1],"extra":1}"#)
            .unwrap_err();
        assert!(err.to_string().contains("unknown field"), "{err}");
    }

    #[test]
    fn corner_types_filter_normalizes_blanks_and_duplicates() {
        let out = normalize_corner_types_filter(Some(vec![
            " role ".into(),
            "".into(),
            "ROLE".into(),
            "scene".into(),
            "scene".into(),
            "   ".into(),
        ]))
        .unwrap();
        assert_eq!(out, Some(vec!["role".to_string(), "scene".to_string()]));
    }

    #[test]
    fn corner_types_filter_empty_after_trim_is_none() {
        let out = normalize_corner_types_filter(Some(vec!["".into(), "   ".into(), "\n\t".into()]))
            .unwrap();
        assert_eq!(out, None);
    }

    #[test]
    fn corner_types_filter_rejects_unknown_value() {
        let err = normalize_corner_types_filter(Some(vec!["clip".into()])).unwrap_err();
        match err {
            ApiError::BadRequest(msg) => assert!(msg.contains("role, scene, or tool")),
            other => panic!("unexpected error: {other:?}"),
        }
    }
}
