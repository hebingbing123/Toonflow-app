use super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn storyboard_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/storyboards/1",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
