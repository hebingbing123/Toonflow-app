use super::super::super::helpers::*;
use axum::http::StatusCode;

#[tokio::test]
async fn project_assets_list_query_unauthorized_without_bearer() {
    let (status, v) =
        get_json("/api/v1/projects/00000000-0000-0000-0000-000000000001/assets?script_numeric_id=1&page=1&limit=10").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}
