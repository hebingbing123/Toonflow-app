use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

const SMOKE_PROJECT_UUID: &str = "00000000-0000-0000-0000-000000000001";

#[tokio::test]
async fn project_novel_events_list_unauthorized_without_bearer() {
    let (status, v) = get_json(&format!(
        "/api/v1/projects/{SMOKE_PROJECT_UUID}/novel-events"
    ))
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_novel_events_list_bad_page_requires_database_before_validation() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novel-events?page=0&limit=20"),
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novel_events_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novel-events?page=1&limit=20"),
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn novel_events_generate_unauthorized_without_bearer() {
    let (status, v) = post_json(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novel-events/generate-events"),
        r#"{"novelIds":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn novel_events_generate_validates_payload_before_database() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novel-events/generate-events");
    let (status, v) = post_json_bearer(&uri, &token, r#"{"novelIds":[]}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");

    let (status, v) =
        post_json_bearer(&uri, &token, r#"{"novelIds":[1],"concurrentCount":0}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");

    let (status, v) =
        post_json_bearer(&uri, &token, r#"{"novelIds":[1],"concurrentCount":9999}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn novel_events_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novel-events/generate-events"),
        &token,
        r#"{"novelIds":[1],"concurrentCount":5}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novel_events_batch_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        &format!("/api/v1/projects/{SMOKE_PROJECT_UUID}/novel-events/batch-delete"),
        &token,
        r#"{"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
