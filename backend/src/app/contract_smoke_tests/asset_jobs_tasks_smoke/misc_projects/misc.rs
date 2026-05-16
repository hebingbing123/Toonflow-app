use super::super::super::helpers::*;
use axum::http::StatusCode;

#[tokio::test]
async fn usage_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/usage/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn prompts_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/prompts").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn prompts_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/prompts/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn agents_memory_query_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/agents/memory/query",
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn scripts_export_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/scripts/export", r#"{"numeric_ids":[1]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}
