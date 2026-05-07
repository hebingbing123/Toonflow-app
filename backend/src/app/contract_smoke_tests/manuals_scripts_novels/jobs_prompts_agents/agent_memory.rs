use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn agents_memory_query_rejects_missing_project_before_db() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/agents/memory/query",
        &token,
        r#"{"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "v={v}");
}

#[tokio::test]
async fn agents_memory_query_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/agents/memory/query",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn agents_memory_clear_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/agents/memory/clear",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn agents_memory_append_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/agents/memory/append",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent","content":"smoke"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn agents_memory_append_rejects_scoped_tier_without_scope_signature_before_db() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/agents/memory/append",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent","content":"smoke","memoryTier":"stage_summary"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "v={v}");
    assert_eq!(
        v["message"].as_str(),
        Some("memoryTier stage_summary requires a non-empty scopeSignature")
    );
}

#[tokio::test]
async fn agents_memory_query_rejects_scoped_tier_without_scope_signature_before_db() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/agents/memory/query",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent","memoryType":"all","memoryTier":"delta_memory"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "v={v}");
    assert_eq!(
        v["message"].as_str(),
        Some("memoryTier delta_memory requires a non-empty scopeSignature")
    );
}
