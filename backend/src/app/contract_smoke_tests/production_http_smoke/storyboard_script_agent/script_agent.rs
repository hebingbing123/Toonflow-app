use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn script_agent_get_plan_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/script-agent/get-plan-data",
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn script_agent_get_plan_database_error_without_pool_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/script-agent/get-plan-data",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_agent_set_plan_database_error_without_pool_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/script-agent/set-plan-data",
        &token,
        r#"{"projectId":1,"agentType":"scriptAgent","data":{"storySkeleton":"","adaptationStrategy":"","script":[]}}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_agent_update_data_database_error_without_pool_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/script-agent/update-data",
        &token,
        r#"{"id":1,"data":{"storySkeleton":"","adaptationStrategy":"","script":[{"id":1,"content":""}]}}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
