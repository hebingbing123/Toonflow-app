use super::query::{
    first_text_model_composite_id, list_filtered, lookup_detail, vendor_catalog_summaries,
};
use super::types::PatchTextModelDefaultBody;

#[test]
fn all_excludes_video() {
    let n = list_filtered("all")
        .iter()
        .filter(|e| e.kind == "video")
        .count();
    assert_eq!(n, 0);
}

#[test]
fn detail_round_trip() {
    let d = lookup_detail("1:gpt-4o-mini").expect("detail");
    assert_eq!(d.model_name, "gpt-4o-mini");
    assert_eq!(d.kind, "text");
}

#[test]
fn first_text_model_is_gpt4o_mini() {
    assert_eq!(first_text_model_composite_id(), "1:gpt-4o-mini");
}

#[test]
fn vendor_catalog_summaries_non_empty() {
    let s = vendor_catalog_summaries();
    assert!(!s.is_empty());
    let openai = s.iter().find(|v| v.id == 1).expect("vendor 1");
    assert!(!openai.name.is_empty());
    assert!(openai.model_count > 0);
    assert!(!openai.model_kinds.is_empty());
}

#[test]
fn patch_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<PatchTextModelDefaultBody>(r#"{"model_id":"1:x","extra":1}"#)
        .unwrap_err();
    assert!(
        err.to_string().contains("unknown field"),
        "expected unknown field error, got: {err}"
    );
}

#[test]
fn patch_body_accepts_null_model_id() {
    let b: PatchTextModelDefaultBody = serde_json::from_str(r#"{"model_id":null}"#).expect("parse");
    assert!(b.model_id.is_none());
}

#[test]
fn patch_body_accepts_valid_model_id() {
    let b: PatchTextModelDefaultBody =
        serde_json::from_str(r#"{"model_id":"1:gpt-4o-mini"}"#).expect("parse");
    assert_eq!(b.model_id.as_deref(), Some("1:gpt-4o-mini"));
}
