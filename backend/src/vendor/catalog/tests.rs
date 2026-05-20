use super::query::{
    first_text_model_composite_id, list_filtered, lookup_detail, vendor_catalog_summaries,
};
use super::types::PatchTextModelDefaultBody;

#[test]
fn all_excludes_video() {
    let n = list_filtered("all", false)
        .iter()
        .filter(|e| e.kind == "video")
        .count();
    assert_eq!(n, 0);
}

#[test]
fn detail_round_trip() {
    let d = lookup_detail("1:gpt-4o-mini", false).expect("detail");
    assert_eq!(d.model_id, "1:gpt-4o-mini");

    let priced = lookup_detail("1:gpt-4o-mini", true).expect("priced detail");
    assert!(priced.pricing.is_some());

    let est = super::pricing::build_estimate(&super::pricing::BillingEstimateRequest {
        model_id: "1:gpt-4o-mini".into(),
        task_kind: "text_completion".into(),
        quantity: 2,
    })
    .expect("estimate");
    assert_eq!(est.credits, 2);
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
    assert_eq!(openai.protocol, "openai");
}

#[test]
fn kling_summary_exposes_video_gateway_meta() {
    let s = vendor_catalog_summaries();
    let kling = s.iter().find(|v| v.id == 4).expect("kling");
    assert_eq!(kling.video_provider.as_deref(), Some("kling"));
    assert_eq!(
        kling.official_api_host.as_deref(),
        Some("https://api.klingai.com")
    );
}

#[test]
fn ollama_and_qwen_catalog_endpoints() {
    let s = vendor_catalog_summaries();
    let ollama = s.iter().find(|v| v.id == 5).expect("ollama vendor");
    assert!(ollama.api_key_optional);
    assert!(ollama
        .default_base_url
        .as_deref()
        .unwrap_or("")
        .contains("11434"));
    let qwen = s.iter().find(|v| v.id == 7).expect("qwen vendor");
    assert!(qwen
        .default_base_url
        .as_deref()
        .unwrap_or("")
        .contains("dashscope"));
    assert!(lookup_detail("7:qwen-turbo", false).is_some());
}

#[test]
fn mainstream_cloud_vendors_in_catalog() {
    assert!(lookup_detail("8:deepseek-chat", false).is_some());
    assert!(lookup_detail("9:glm-4-plus", false).is_some());
    assert!(lookup_detail("10:moonshot-v1-32k", false).is_some());
    assert!(lookup_detail("12:deepseek-ai/DeepSeek-V3", false).is_some());
    assert!(lookup_detail("15:gemini-2.0-flash", false).is_some());
    assert!(lookup_detail("16:claude-3-5-sonnet-20241022", false).is_some());
    assert!(lookup_detail("20:doubao-seedance-1-0-pro", false).is_some());
    assert!(lookup_detail("7:qwen-vl-max", false).is_some());
    assert_eq!(
        super::protocol::vendor_protocol(16),
        super::protocol::VendorProtocol::Anthropic
    );
    assert_eq!(
        super::protocol::vendor_protocol(15),
        super::protocol::VendorProtocol::GeminiNative
    );
    let s = vendor_catalog_summaries();
    assert!(s.iter().any(|v| v.id == 8));
    assert!(s.iter().any(|v| v.id == 22));
}

#[test]
fn multimodal_list_filter_includes_vision_models() {
    let mm = super::query::list_filtered("multimodal", false);
    assert!(mm
        .iter()
        .any(|e| format!("{}:{}", e.id, e.value) == "7:qwen-vl-max"));
}

#[test]
fn native_image_models_in_catalog() {
    assert!(lookup_detail("18:doubao-seedream-3-0-t2i", false).is_some());
    assert!(lookup_detail("15:imagen-3.0-generate-002", false).is_some());
    assert!(lookup_detail("7:wanx2.1-t2i-turbo", false).is_some());
    let images = super::query::list_filtered("image", false);
    assert!(images
        .iter()
        .any(|e| format!("{}:{}", e.id, e.value) == "18:doubao-seedream-3-0-t2i"));
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
