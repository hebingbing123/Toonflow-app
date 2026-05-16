//! 艺术风格模块单元测试。

use crate::error::ApiError;

use super::{
    parse_uploaded_cover, CreateArtStyleBody, ExtractArtStylePromptBody, PatchArtStyleBody,
};

#[test]
fn create_art_style_body_accepts_minimal() {
    let j = serde_json::json!({ "name": "test" });
    let b: CreateArtStyleBody = serde_json::from_value(j).unwrap();
    assert_eq!(b.name, "test");
}

#[test]
fn patch_art_style_body_rejects_unknown_fields() {
    let j = serde_json::json!({ "name": "x", "extra": 1 });
    assert!(serde_json::from_value::<PatchArtStyleBody>(j).is_err());
}

#[test]
fn extract_art_style_prompt_body_accepts_images() {
    let j = serde_json::json!({ "images": ["https://example.com/a.png"] });
    let b: ExtractArtStylePromptBody = serde_json::from_value(j).unwrap();
    assert_eq!(b.images.len(), 1);
}

#[test]
fn extract_art_style_prompt_body_rejects_unknown_fields() {
    let j = serde_json::json!({ "images": [], "extra": 1 });
    assert!(serde_json::from_value::<ExtractArtStylePromptBody>(j).is_err());
}

#[test]
fn parse_uploaded_cover_accepts_png_data_uri() {
    let parsed = parse_uploaded_cover("data:image/png;base64,AA==")
        .expect("parse")
        .expect("cover");
    assert_eq!(parsed.ext, "png");
    assert_eq!(parsed.bytes, vec![0]);
}

#[test]
fn parse_uploaded_cover_treats_http_url_as_passthrough() {
    assert!(parse_uploaded_cover("https://example.com/cover.png")
        .expect("parse")
        .is_none());
}

#[test]
fn parse_uploaded_cover_rejects_non_image_data_uri() {
    let err = parse_uploaded_cover("data:text/plain;base64,AA==").expect_err("bad mime");
    assert!(matches!(err, ApiError::BadRequest(_)));
}
