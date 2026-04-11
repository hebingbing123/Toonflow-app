use serde_json::Value;
use uuid::Uuid;

use super::dto::{
    BatchDeleteEventsBody, BatchDeleteEventsResponse, CreateNovelEventBody, EventWithChapters,
    LegacyGetEventsBody, ListNovelEventsQuery, UpdateNovelEventBody,
};
use super::query::{self, search_ilike};

#[test]
fn create_novel_event_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<CreateNovelEventBody>(r#"{"name":"Event","extra":1}"#);
    assert!(err.is_err());
}

#[test]
fn create_novel_event_body_accepts_minimal() {
    let b: CreateNovelEventBody = serde_json::from_str(r#"{"name":"Test Event"}"#).unwrap();
    assert_eq!(b.name, "Test Event");
    assert_eq!(b.detail, None);
    assert!(b.chapter_ids.is_empty());
}

#[test]
fn create_novel_event_body_accepts_full() {
    let b: CreateNovelEventBody =
        serde_json::from_str(r#"{"name":"Event","detail":"Details","chapterIds":[1,2,3]}"#)
            .unwrap();
    assert_eq!(b.name, "Event");
    assert_eq!(b.detail, Some("Details".to_string()));
    assert_eq!(b.chapter_ids, vec![1, 2, 3]);
}

#[test]
fn update_novel_event_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<UpdateNovelEventBody>(r#"{"name":"New","extra":1}"#);
    assert!(err.is_err());
}

#[test]
fn update_novel_event_body_accepts_name_only() {
    let b: UpdateNovelEventBody = serde_json::from_str(r#"{"name":"New Name"}"#).unwrap();
    assert_eq!(b.name, Some("New Name".to_string()));
    assert_eq!(b.detail, None);
    assert_eq!(b.chapter_ids, None);
}

#[test]
fn update_novel_event_body_accepts_detail_clear() {
    let b: UpdateNovelEventBody = serde_json::from_str(r#"{"detail":null}"#).unwrap();
    // Verify that detail was parsed (it's Some(Value::Null) when null is explicitly provided)
    assert!(b.detail.is_some());
}

#[test]
fn update_novel_event_body_accepts_detail_string() {
    let b: UpdateNovelEventBody = serde_json::from_str(r#"{"detail":"New detail"}"#).unwrap();
    assert_eq!(b.detail, Some(Value::String("New detail".to_string())));
}

#[test]
fn update_novel_event_body_accepts_chapter_ids() {
    let b: UpdateNovelEventBody = serde_json::from_str(r#"{"chapterIds":[10,20]}"#).unwrap();
    assert_eq!(b.chapter_ids, Some(vec![10, 20]));
}

#[test]
fn batch_delete_events_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<BatchDeleteEventsBody>(r#"{"ids":[1,2],"extra":1}"#);
    assert!(err.is_err());
}

#[test]
fn batch_delete_events_body_accepts_valid() {
    let b: BatchDeleteEventsBody = serde_json::from_str(r#"{"ids":[1,2,3]}"#).unwrap();
    assert_eq!(b.ids, vec![1, 2, 3]);
}

#[test]
fn legacy_get_events_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<LegacyGetEventsBody>(
        r#"{"projectId":1,"page":1,"limit":20,"extra":1}"#,
    );
    assert!(err.is_err());
}

#[test]
fn legacy_get_events_body_accepts_valid() {
    let b: LegacyGetEventsBody =
        serde_json::from_str(r#"{"projectId":1,"page":1,"limit":20}"#).unwrap();
    assert_eq!(b.project_id, 1);
    assert_eq!(b.page, 1);
    assert_eq!(b.limit, 20);
    assert_eq!(b.search, None);
}

#[test]
fn legacy_get_events_body_accepts_with_search() {
    let b: LegacyGetEventsBody =
        serde_json::from_str(r#"{"projectId":1,"page":1,"limit":20,"search":"test"}"#).unwrap();
    assert_eq!(b.search, Some("test".to_string()));
}

#[test]
fn search_ilike_returns_none_for_empty() {
    assert_eq!(search_ilike(None), None);
    assert_eq!(search_ilike(Some("".to_string())), None);
    assert_eq!(search_ilike(Some("   ".to_string())), None);
}

#[test]
fn search_ilike_returns_pattern_for_valid() {
    assert_eq!(
        search_ilike(Some("test".to_string())),
        Some("%test%".to_string())
    );
    assert_eq!(
        search_ilike(Some("  test  ".to_string())),
        Some("%test%".to_string())
    );
}

#[test]
fn event_query_row_into_event_with_chapters() {
    let row = query::EventQueryRow {
        id: Uuid::new_v4(),
        project_id: Uuid::new_v4(),
        legacy_id: 1,
        name: "Test Event".to_string(),
        detail: "Details".to_string(),
        create_time_ms: Some(1234567890),
        chapter_indexes: vec![1, 2, 3],
    };
    let event: EventWithChapters = row.into();
    assert_eq!(event.legacy_id, 1);
    assert_eq!(event.name, "Test Event");
    assert_eq!(event.detail, "Details");
    assert_eq!(event.create_time_ms, Some(1234567890));
    assert_eq!(event.chapter_indexes, vec![1, 2, 3]);
}

#[test]
fn list_novel_events_query_defaults() {
    let q: ListNovelEventsQuery = serde_json::from_str(r#"{}"#).unwrap();
    assert_eq!(q.search, None);
    assert_eq!(q.page, None);
    assert_eq!(q.limit, None);
}

#[test]
fn batch_delete_response_serialize() {
    let resp = BatchDeleteEventsResponse {
        message: "删除成功",
    };
    let json = serde_json::to_string(&resp).unwrap();
    assert!(json.contains("删除成功"));
}
