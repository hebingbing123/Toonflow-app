use super::super::super::helpers::*;
use axum::http::StatusCode;

#[tokio::test]
async fn scripts_extract_state_poll_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/scripts/extract-state/poll",
        r#"{"numeric_ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn scripts_extract_assets_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/scripts/extract-assets",
        r#"{"project_numeric_id":1,"script_numeric_ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn storyboards_by_project_script_unauthorized_without_bearer() {
    let (status, v) =
        get_json("/api/v1/projects/00000000-0000-0000-0000-000000000001/scripts/1/storyboards")
            .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn storyboard_by_project_unauthorized_without_bearer() {
    let (status, v) =
        get_json("/api/v1/projects/00000000-0000-0000-0000-000000000001/storyboards/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}
