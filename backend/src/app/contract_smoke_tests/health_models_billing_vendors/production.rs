use super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn production_get_production_data_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/production/get-production-data",
        r#"{"projectId":1,"scriptId":1,"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn production_get_production_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/get-production-data",
        &token,
        r#"{"projectId":1,"scriptId":1,"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn production_get_production_data_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/production/get-production-data",
        &token,
        r#"{"projectId":1,"scriptId":1,"ids":[0]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}
