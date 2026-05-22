use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

const SMOKE_PROJECT_UUID: &str = "00000000-0000-0000-0000-000000000001";

const SAMPLE_IMPORT_BODY: &str = r#"{
  "content_hash": "deadbeef",
  "total_chapters": 1,
  "chapters": [
    {"chapter_index": 1, "chapter": "第一章", "chapter_data": "正文"}
  ],
  "intake_status": "admitted"
}"#;

#[tokio::test]
async fn whole_book_import_session_unauthorized_without_bearer() {
    let (status, v) = get_json(&format!(
        "/api/v1/projects/{SMOKE_PROJECT_UUID}/novels/whole-book-import/session"
    ))
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn whole_book_import_session_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novels/whole-book-import/session"),
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn whole_book_import_post_unauthorized_without_bearer() {
    let (status, v) = post_json(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novels/whole-book-import"),
        SAMPLE_IMPORT_BODY,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn whole_book_import_post_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novels/whole-book-import"),
        &token,
        SAMPLE_IMPORT_BODY,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
