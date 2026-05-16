use super::super::super::helpers::*;
use super::super::WB_PROJECT;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn project_assets_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        get_json_bearer(&format!("/api/v1/projects/{WB_PROJECT}/assets"), &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
