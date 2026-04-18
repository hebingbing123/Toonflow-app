use super::super::super::super::helpers::*;
use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::header;
use axum::http::Method;
use axum::http::Request;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn settings_dev_switch_get_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/settings/dev/switch-ai-tool").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn settings_dev_switch_get_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/settings/dev/switch-ai-tool", &token).await;
    assert_eq!(status, StatusCode::OK);
    let val = v["value"].as_str().expect("value");
    assert!(val == "0" || val == "1");
}

#[tokio::test]
async fn settings_dev_switch_put_updates_process_local_value_with_jwt() {
    let state = smoke_state();
    let token = test_jwt(Uuid::nil());
    let (status, v) = oneshot_json_state(
        state.clone(),
        Request::builder()
            .method(Method::PUT)
            .uri("/api/v1/settings/dev/switch-ai-tool")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(r#"{"value":"1"}"#.to_string()))
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["value"], "1");

    let (status, v) = oneshot_json_state(
        state,
        Request::builder()
            .uri("/api/v1/settings/dev/switch-ai-tool")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["value"], "1");
}

#[tokio::test]
async fn settings_dev_switch_put_rejects_non_binary_value_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = put_json_bearer(
        "/api/v1/settings/dev/switch-ai-tool",
        &token,
        r#"{"value":"2"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}
