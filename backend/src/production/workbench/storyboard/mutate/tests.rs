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

#[test]
fn update_duration_body_validates_positive_duration() {
    use super::types::UpdateStoryboardDurationBody;
    use serde_json;

    // Valid duration
    let valid = serde_json::from_str::<UpdateStoryboardDurationBody>(
        r#"{"projectId":1,"scriptId":2,"storyboardId":3,"duration":5}"#,
    );
    assert!(valid.is_ok());
    assert_eq!(valid.unwrap().duration, 5);

    // Zero duration should be rejected by handler, not deserialization
    let zero = serde_json::from_str::<UpdateStoryboardDurationBody>(
        r#"{"projectId":1,"scriptId":2,"storyboardId":3,"duration":0}"#,
    );
    assert!(zero.is_ok());

    // Negative duration should be rejected by handler, not deserialization
    let negative = serde_json::from_str::<UpdateStoryboardDurationBody>(
        r#"{"projectId":1,"scriptId":2,"storyboardId":3,"duration":-1}"#,
    );
    assert!(negative.is_ok());
}

#[test]
fn update_duration_body_rejects_unknown_fields() {
    use super::types::UpdateStoryboardDurationBody;
    use serde_json;

    let err = serde_json::from_str::<UpdateStoryboardDurationBody>(
        r#"{"projectId":1,"scriptId":2,"storyboardId":3,"duration":5,"extra":"field"}"#,
    );
    assert!(err.is_err());
}
