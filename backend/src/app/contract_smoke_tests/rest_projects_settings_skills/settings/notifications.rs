use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn settings_notifications_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/settings/notifications").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/settings/notifications", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_mark_read_unauthorized_without_bearer() {
    let body = r#"{"ids":[1],"read":true}"#;
    let (status, v) = post_json("/api/v1/settings/notifications/mark-read", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_mark_read_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"ids":[1],"read":true}"#;
    let (status, v) =
        post_json_bearer("/api/v1/settings/notifications/mark-read", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_notifications_mark_all_read_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/settings/notifications/mark-all-read", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_notifications_mark_all_read_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/settings/notifications/mark-all-read", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
