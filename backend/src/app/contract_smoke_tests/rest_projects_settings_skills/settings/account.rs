use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn settings_account_exports_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/settings/account/exports").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_account_exports_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/settings/account/exports", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_account_export_post_unauthorized_without_bearer() {
    let body = r#"{"includeAuditLogs":false,"includeNotifications":true}"#;
    let (status, v) = post_json("/api/v1/settings/account/export", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_account_export_post_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"includeAuditLogs":false,"includeNotifications":true}"#;
    let (status, v) = post_json_bearer("/api/v1/settings/account/export", &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_account_delete_post_unauthorized_without_bearer() {
    let body = r#"{"confirmPhrase":"DELETE MY ACCOUNT","acknowledgeIrreversible":true}"#;
    let (status, v) = post_json("/api/v1/settings/account/delete", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_account_delete_post_validates_confirm_phrase_before_db() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"confirmPhrase":"NOPE","acknowledgeIrreversible":true}"#;
    let (status, v) = post_json_bearer("/api/v1/settings/account/delete", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}
