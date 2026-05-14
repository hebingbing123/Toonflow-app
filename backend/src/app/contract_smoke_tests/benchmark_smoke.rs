use super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn benchmark_cases_unauthorized_without_bearer() {
    let (status, value) = get_json("/api/v1/benchmark/cases").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(value["code"], "unauthorized");
}

#[tokio::test]
async fn benchmark_cases_require_database_with_bearer() {
    let token = test_jwt(Uuid::nil());
    let (status, value) = get_json_bearer("/api/v1/benchmark/cases", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(value["code"], "database_error");
}

#[tokio::test]
async fn benchmark_review_queue_unauthorized_without_bearer() {
    let (status, value) = get_json("/api/v1/benchmark/review-queue").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(value["code"], "unauthorized");
}

#[tokio::test]
async fn benchmark_review_queue_requires_database_with_bearer() {
    let token = test_jwt(Uuid::nil());
    let (status, value) = get_json_bearer("/api/v1/benchmark/review-queue", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(value["code"], "database_error");
}

#[tokio::test]
async fn benchmark_memory_profiles_ok_with_bearer_without_database() {
    let token = test_jwt(Uuid::nil());
    let (status, value) = get_json_bearer("/api/v1/benchmark/memory-profiles", &token).await;
    assert_eq!(status, StatusCode::OK);
    let profiles = value["profiles"].as_array().expect("profiles array");
    assert!(
        !profiles.is_empty(),
        "expected default memory budget profiles"
    );
}

#[tokio::test]
async fn benchmark_trends_require_database_with_bearer() {
    let token = test_jwt(Uuid::nil());
    let (status, value) = get_json_bearer("/api/v1/benchmark/trends", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(value["code"], "database_error");
}

#[tokio::test]
async fn benchmark_experiment_roi_requires_database_with_bearer() {
    let token = test_jwt(Uuid::nil());
    let experiment_id = Uuid::nil();
    let (status, value) = get_json_bearer(
        &format!("/api/v1/benchmark/experiments/{experiment_id}/roi"),
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(value["code"], "database_error");
}
