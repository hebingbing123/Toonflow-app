use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn settings_agent_deploy_list_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/settings/agent-deploy/list", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_agent_deploy_list_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/settings/agent-deploy/list", &token, "{}").await;
    assert_eq!(status, StatusCode::OK);
    let arr = v.as_array().expect("array body");
    assert_eq!(arr.len(), 4);
    assert_eq!(arr[0]["key"], "scriptAgent");
    assert_eq!(arr[3]["key"], "ttsDubbing");
    assert_eq!(arr[3]["disabled"], true);
}

#[tokio::test]
async fn settings_agent_deploy_deploy_model_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/settings/agent-deploy/deploy-model",
        &token,
        r#"{"id":1,"name":"剧本Agent","model":"x","modelName":"y","vendorId":null,"desc":"z"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn settings_agent_deploy_set_key_noop_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/settings/agent-deploy/set-key", &token, "{}").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        v["message"],
        "未通过 HTTP 保存密钥；请在服务端环境变量或密钥管理中配置"
    );
}
