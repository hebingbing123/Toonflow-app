use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn corner_scape_assets_accepts_blank_types_entries_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/corner-scape",
        &token,
        r#"{"types":[" ","\n\t",""]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn corner_scape_assets_accepts_duplicate_types_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/assets/corner-scape",
        &token,
        r#"{"types":["role","ROLE","scene","scene"]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
