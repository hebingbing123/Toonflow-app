use super::super::super::super::helpers::*;
use super::assert_auth_not_configured_with_bearer;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn projects_summary_auth_not_configured_without_jwt_secret_even_with_bearer() {
    assert_auth_not_configured_with_bearer("/api/v1/projects/summary").await;
}

#[tokio::test]
async fn harness_tools_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, value) = get_json_bearer("/api/v1/harness/tools", &token).await;
    assert_eq!(status, StatusCode::OK);
    let tools = value["tools"].as_array().expect("tools array");
    assert!(!tools.is_empty());
    let names: Vec<&str> = tools
        .iter()
        .filter_map(|tool| tool["name"].as_str())
        .collect();
    assert!(names.contains(&"echo"));
    assert!(names.contains(&"wasm.probe"));
}

#[tokio::test]
async fn skills_summary_ok_with_jwt_when_skills_tree_present() {
    let token = test_jwt(Uuid::nil());
    let (status, value) = get_json_bearer("/api/v1/skills/summary", &token).await;
    assert_eq!(status, StatusCode::OK);
    assert!(
        value["markdown_file_count"].as_u64().unwrap_or(0) > 0,
        "repo ships backend/data/skills markdown"
    );
    assert_eq!(
        value["scope"].as_str(),
        Some("user"),
        "scope field should be present and set to 'user'"
    );
}
