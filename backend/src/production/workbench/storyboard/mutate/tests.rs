use super::super::common::{normalize_storyboard_image_url, normalize_storyboard_prompt};
use crate::error::ApiError;

#[test]
fn normalize_storyboard_prompt_trims_value() {
    let prompt = normalize_storyboard_prompt("  opening frame  ").unwrap();
    assert_eq!(prompt, "opening frame");
}

#[test]
fn normalize_storyboard_prompt_rejects_blank_value() {
    let err = normalize_storyboard_prompt("   ").unwrap_err();
    assert!(matches!(
        err,
        ApiError::BadRequest(message) if message == "prompt must not be empty"
    ));
}

#[test]
fn normalize_storyboard_image_url_trims_value() {
    let image_url = normalize_storyboard_image_url("  https://example.com/frame.png  ").unwrap();
    assert_eq!(image_url, "https://example.com/frame.png");
}

#[test]
fn normalize_storyboard_image_url_rejects_blank_value() {
    let err = normalize_storyboard_image_url(" ").unwrap_err();
    assert!(matches!(
        err,
        ApiError::BadRequest(message) if message == "imageUrl must not be empty"
    ));
}
