use super::dto::{CreateStoryboardBody, PatchStoryboardBody};

#[test]
fn patch_storyboard_body_rejects_unknown_fields() {
    let err =
        serde_json::from_str::<PatchStoryboardBody>(r#"{"prompt":"x","extra":1}"#).unwrap_err();
    assert!(
        err.to_string().contains("unknown field") || err.to_string().contains("unknown variant"),
        "{err}"
    );
}

#[test]
fn create_storyboard_body_accepts_empty() {
    let b: CreateStoryboardBody = serde_json::from_str("{}").unwrap();
    assert!(b.prompt.is_none());
}

#[test]
fn create_storyboard_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<CreateStoryboardBody>(r#"{"prompt":"a","x":1}"#).unwrap_err();
    assert!(
        err.to_string().contains("unknown field") || err.to_string().contains("unknown variant"),
        "{err}"
    );
}
