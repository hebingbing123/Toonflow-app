use super::super::super::super::helpers::*;
use axum::http::StatusCode;

#[tokio::test]
async fn skills_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skills_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills/content?path=script_execution_script.md").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_binary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills/binary?path=_smoke/binary_probe.png").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}
