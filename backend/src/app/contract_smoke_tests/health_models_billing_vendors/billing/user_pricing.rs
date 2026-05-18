use crate::app::contract_smoke_tests::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

async fn assert_get_unauthorized(uri: &str) {
    let (status, value) = get_json(uri).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(value["code"], "unauthorized");
}

#[tokio::test]
async fn billing_estimate_unauthorized_without_bearer() {
    let body = r#"{"model_id":"1:gpt-4o-mini","task_kind":"text_completion"}"#;
    let (status, value) = post_json("/api/v1/billing/estimate", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(value["code"], "unauthorized");
}

#[tokio::test]
async fn billing_estimate_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = serde_json::json!({
        "model_id": "1:gpt-4o-mini",
        "task_kind": "text_completion",
        "quantity": 4
    })
    .to_string();
    let (status, value) = post_json_bearer("/api/v1/billing/estimate", &token, &body).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(value["model_id"], "1:gpt-4o-mini");
    assert!(value["credits"].as_u64().unwrap_or(0) > 0);
    assert!(value["warnings"]
        .as_array()
        .map(|a| a.iter().any(|w| w == "estimate_only"))
        .unwrap_or(false));
}

#[tokio::test]
async fn billing_estimate_unknown_model_404() {
    let token = test_jwt(Uuid::nil());
    let body = serde_json::json!({
        "model_id": "99:missing",
        "task_kind": "text_completion"
    })
    .to_string();
    let (status, _) = post_json_bearer("/api/v1/billing/estimate", &token, &body).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn models_list_include_pricing_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, value) = get_json_bearer("/api/v1/models?include_pricing=true", &token).await;
    assert_eq!(status, StatusCode::OK);
    let arr = value.as_array().expect("array");
    assert!(!arr.is_empty());
    assert!(arr[0]["pricing"].is_object());
    assert!(arr[0]["model_id"].is_string());
}

#[tokio::test]
async fn billing_spend_summary_unauthorized_without_bearer() {
    assert_get_unauthorized("/api/v1/billing/spend-summary").await;
}
