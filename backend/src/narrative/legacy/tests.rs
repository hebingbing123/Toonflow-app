use super::dto::{default_generate_events_concurrency, GenerateNovelEventsBody};
use super::DEFAULT_GENERATE_EVENTS_CONCURRENCY;

#[test]
fn generate_novel_events_body_accepts_valid_payload() {
    let b: GenerateNovelEventsBody =
        serde_json::from_str(r#"{"projectId":1,"novelIds":[11,22],"concurrentCount":3}"#).unwrap();
    assert_eq!(b.project_id, 1);
    assert_eq!(b.novel_ids, vec![11, 22]);
    assert_eq!(b.concurrent_count, 3);
}

#[test]
fn generate_novel_events_body_uses_default_concurrency() {
    let b: GenerateNovelEventsBody =
        serde_json::from_str(r#"{"projectId":1,"novelIds":[11]}"#).unwrap();
    assert_eq!(b.concurrent_count, DEFAULT_GENERATE_EVENTS_CONCURRENCY);
}

#[test]
fn generate_novel_events_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<GenerateNovelEventsBody>(
        r#"{"projectId":1,"novelIds":[11],"extra":true}"#,
    );
    assert!(err.is_err());
}

#[test]
fn default_generate_events_concurrency_matches_constant() {
    assert_eq!(
        default_generate_events_concurrency(),
        DEFAULT_GENERATE_EVENTS_CONCURRENCY
    );
}
