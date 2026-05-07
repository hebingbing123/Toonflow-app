use super::dto::{CreateNovelBody, PatchNovelBody};
use serde_json::{json, Value};

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

#[test]
fn create_novel_body_accepts_intake_fields() {
    let body: CreateNovelBody = serde_json::from_value(json!({
        "chapter": "第一章",
        "chapter_data": "正文",
        "intake_source": "crawler_client",
        "intake_source_url": "https://example.com/book/1",
        "intake_status": "admitted",
        "intake_note": "auto admitted"
    }))
    .expect("deserialize create novel body");

    assert_eq!(body.intake_source.as_deref(), Some("crawler_client"));
    assert_eq!(
        body.intake_source_url.as_deref(),
        Some("https://example.com/book/1")
    );
    assert_eq!(body.intake_status.as_deref(), Some("admitted"));
    assert_eq!(body.intake_note.as_deref(), Some("auto admitted"));
}

#[test]
fn patch_novel_body_accepts_nullable_intake_fields() {
    let body: PatchNovelBody = serde_json::from_value(json!({
        "intake_status": "rejected",
        "intake_source_url": null,
        "intake_note": "needs cleanup"
    }))
    .expect("deserialize patch novel body");

    assert_eq!(body.intake_status, Some(json!("rejected")));
    // Explicit JSON `null` is `Some(Null)` so PATCH can clear the field; omitted keys stay `None`.
    assert_eq!(body.intake_source_url, Some(Value::Null));
    assert_eq!(body.intake_note, Some(json!("needs cleanup")));
}

#[test]
fn list_novels_query_accepts_intake_filters() {
    let query: super::dto::ListNovelsQuery = serde_json::from_value(json!({
        "search": "第一章",
        "intake_status": "pending_review",
        "intake_source": "crawler_client",
        "page": 2,
        "limit": 20
    }))
    .expect("deserialize novels list query");

    assert_eq!(query.search.as_deref(), Some("第一章"));
    assert_eq!(query.intake_status.as_deref(), Some("pending_review"));
    assert_eq!(query.intake_source.as_deref(), Some("crawler_client"));
    assert_eq!(query.page, Some(2));
    assert_eq!(query.limit, Some(20));
}
