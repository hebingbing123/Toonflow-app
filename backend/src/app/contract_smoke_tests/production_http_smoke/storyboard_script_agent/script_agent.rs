use super::{assert_database_error, assert_unauthorized};

#[tokio::test]
async fn script_agent_get_plan_unauthorized_without_bearer() {
    assert_unauthorized(
        "/api/v1/script-agent/get-plan-data",
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
}

#[tokio::test]
async fn script_agent_get_plan_database_error_without_pool_with_jwt() {
    assert_database_error(
        "/api/v1/script-agent/get-plan-data",
        r#"{"projectId":1,"agentType":"scriptAgent"}"#,
    )
    .await;
}

#[tokio::test]
async fn script_agent_set_plan_database_error_without_pool_with_jwt() {
    assert_database_error(
        "/api/v1/script-agent/set-plan-data",
        r#"{"projectId":1,"agentType":"scriptAgent","data":{"storySkeleton":"","adaptationStrategy":"","script":[]}}"#,
    )
    .await;
}

#[tokio::test]
async fn script_agent_update_data_database_error_without_pool_with_jwt() {
    assert_database_error(
        "/api/v1/script-agent/update-data",
        r#"{"id":1,"data":{"storySkeleton":"","adaptationStrategy":"","script":[{"id":1,"content":""}]}}"#,
    )
    .await;
}
