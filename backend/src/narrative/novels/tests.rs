use super::dto::{CreateNovelBody, PatchNovelBody};

#[test]
fn create_novel_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<CreateNovelBody>(r#"{"chapter":"a","x":1}"#).unwrap_err();
    assert!(
        err.to_string().contains("unknown field") || err.to_string().contains("unknown variant"),
        "{err}"
    );
}

#[test]
fn patch_novel_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<PatchNovelBody>(r#"{"chapter":"a","extra":1}"#).unwrap_err();
    assert!(
        err.to_string().contains("unknown field") || err.to_string().contains("unknown variant"),
        "{err}"
    );
}
