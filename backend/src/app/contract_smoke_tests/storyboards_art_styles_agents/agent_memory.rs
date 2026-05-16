use super::super::helpers::*;
use axum::http::StatusCode;

#[tokio::test]
async fn agents_memory_clear_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/agents/memory/clear",
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn agents_memory_append_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/agents/memory/append",
        r#"{"projectId":1,"agentType":"scriptAgent","content":"hi"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}
