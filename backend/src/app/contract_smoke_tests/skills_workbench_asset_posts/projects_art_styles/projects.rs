use super::super::super::helpers::*;
use super::super::WB_PROJECT;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn projects_summary_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects/summary", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn projects_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn projects_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn projects_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_stats_unauthorized_without_bearer() {
    let uri = format!("/api/v1/projects/{WB_PROJECT}/stats");
    let (status, v) = get_json(&uri).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_assets_list_unauthorized_without_bearer() {
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets");
    let (status, v) = get_json(&uri).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn corner_scape_assets_unauthorized_without_bearer() {
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/corner-scape");
    let (status, v) = post_json(&uri, "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn corner_scape_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/corner-scape");
    let (status, v) = post_json_bearer(&uri, &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn corner_scape_assets_rejects_bad_types_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/projects/{WB_PROJECT}/assets/corner-scape");
    let (status, v) = post_json_bearer(&uri, &token, r#"{"types":["clip"]}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}
