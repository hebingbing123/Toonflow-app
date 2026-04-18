use super::super::super::helpers::*;
use axum::body::Body;
use axum::http::header;
use axum::http::Request;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn models_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/models").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

/// With a valid-looking Bearer token, missing JWT secret must yield **503** `auth_not_configured` (not **503** `database_error`).
#[tokio::test]
async fn models_auth_not_configured_without_jwt_secret_even_with_bearer() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = oneshot_json_state(
        smoke_state_without_jwt_secret(),
        Request::builder()
            .uri("/api/v1/models")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .extension(axum::extract::ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "auth_not_configured");
}

#[tokio::test]
async fn projects_summary_auth_not_configured_without_jwt_secret_even_with_bearer() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = oneshot_json_state(
        smoke_state_without_jwt_secret(),
        Request::builder()
            .uri("/api/v1/projects/summary")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .extension(axum::extract::ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "auth_not_configured");
}

#[tokio::test]
async fn models_detail_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/models/detail?model_id=1%3Agpt-4o-mini").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn models_list_ok_with_supabase_style_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/models", &token).await;
    assert_eq!(status, StatusCode::OK);
    let arr = v.as_array().expect("models list is array");
    assert!(!arr.is_empty(), "embedded catalog must expose models");
    assert!(arr[0].get("id").is_some());
    assert!(arr[0].get("model_name").is_none());
    assert!(arr[0].get("value").is_some());
}

#[tokio::test]
async fn harness_tools_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/harness/tools", &token).await;
    assert_eq!(status, StatusCode::OK);
    let tools = v["tools"].as_array().expect("tools array");
    assert!(!tools.is_empty());
    let names: Vec<&str> = tools.iter().filter_map(|t| t["name"].as_str()).collect();
    assert!(names.contains(&"echo"));
    assert!(names.contains(&"wasm.probe"));
}

#[tokio::test]
async fn skills_summary_ok_with_jwt_when_skills_tree_present() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/skills/summary", &token).await;
    assert_eq!(status, StatusCode::OK);
    assert!(
        v["markdown_file_count"].as_u64().unwrap_or(0) > 0,
        "repo ships backend/data/skills markdown"
    );
}

#[tokio::test]
async fn models_detail_ok_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = "/api/v1/models/detail?model_id=1%3Agpt-4o-mini";
    let (status, v) = get_json_bearer(uri, &token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["model_name"], "gpt-4o-mini");
    assert_eq!(v["vendor_id"], 1);
    assert_eq!(v["type"], "text");
}
