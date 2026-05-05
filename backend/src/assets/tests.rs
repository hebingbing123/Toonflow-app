//! 资产模块单元测试。

use crate::error::ApiError;
use crate::http_kit::json_patch::FieldPatch;

use super::models::*;
use super::utils::*;

#[test]
fn patch_asset_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<PatchAssetBody>(r#"{"name":"a","x":1}"#).unwrap_err();
    assert!(
        err.to_string().contains("unknown field") || err.to_string().contains("unknown variant"),
        "{err}"
    );
}

#[test]
fn patch_asset_body_accepts_cover_numeric_image_id_only() {
    let b: PatchAssetBody = serde_json::from_str(r#"{"cover_numeric_image_id":42}"#).unwrap();
    assert!(b.name.is_none());
    assert_eq!(
        crate::http_kit::json_patch::parse_optional_i32_field(b.cover_numeric_image_id, "c")
            .unwrap(),
        FieldPatch::Set(Some(42))
    );
}

#[test]
fn patch_asset_body_accepts_candidate_status_only() {
    let b: PatchAssetBody = serde_json::from_str(r#"{"candidate_status":"linked"}"#).unwrap();
    assert!(b.name.is_none());
    assert!(b.candidate_status.is_some());
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
        err.to_string().contains("unknown field") || err.to_string().contains("unknown variant"),
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
    let err = serde_json::from_str::<PatchAssetImageBody>(r#"{"state":"x","x":1}"#).unwrap_err();
    assert!(
        err.to_string().contains("unknown field") || err.to_string().contains("unknown variant"),
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
fn upload_clip_body_accepts_type_alias_key() {
    let body: WorkbenchUploadClipBody =
        serde_json::from_str(r#"{"base64Data":"AA==","type":"clip","name":"demo"}"#).unwrap();
    assert_eq!(body.asset_type.as_deref(), Some("clip"));
    assert_eq!(body.name, "demo");
}

#[test]
fn workbench_nested_assets_body_accepts_minimal() {
    let body: WorkbenchNestedAssetsBody = serde_json::from_str(r#"{"type":"role"}"#).unwrap();
    assert_eq!(body.asset_type, "role");
    assert!(body.name.is_none());
    assert!(body.page.is_none());
    assert!(body.limit.is_none());
}

#[test]
fn workbench_nested_assets_body_rejects_unknown_fields() {
    let err =
        serde_json::from_str::<WorkbenchNestedAssetsBody>(r#"{"type":"role","x":1}"#).unwrap_err();
    assert!(
        err.to_string().contains("unknown field") || err.to_string().contains("unknown variant"),
        "{err}"
    );
}

#[test]
fn workbench_add_assets_body_accepts_minimal() {
    let body: WorkbenchAddAssetsBody =
        serde_json::from_str(r#"{"name":"Hero","describe":"Main role","type":"role"}"#).unwrap();
    assert_eq!(body.name, "Hero");
    assert_eq!(body.asset_type, "role");
}

#[test]
fn workbench_save_assets_body_accepts_image_id_without_base64() {
    let body: WorkbenchSaveAssetsBody =
        serde_json::from_str(r#"{"id":1,"type":"role","imageId":3}"#).unwrap();
    assert_eq!(body.id, 1);
    assert_eq!(body.image_id, Some(3));
}

#[test]
fn workbench_batch_delete_assets_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<WorkbenchBatchDeleteAssetsBody>(r#"{"id":[1],"extra":1}"#)
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
    let out =
        normalize_corner_types_filter(Some(vec!["".into(), "   ".into(), "\n\t".into()])).unwrap();
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
