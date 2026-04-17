use super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn projects_create_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/projects", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn projects_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/projects", &token, "{}").await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn scripts_extract_state_poll_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/scripts/extract-state/poll",
        r#"{"numeric_ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn scripts_extract_assets_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/scripts/extract-assets",
        r#"{"project_numeric_id":1,"script_numeric_ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn storyboards_by_project_script_unauthorized_without_bearer() {
    let (status, v) =
        get_json("/api/v1/projects/00000000-0000-0000-0000-000000000001/scripts/1/storyboards")
            .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn storyboard_by_project_unauthorized_without_bearer() {
    let (status, v) =
        get_json("/api/v1/projects/00000000-0000-0000-0000-000000000001/storyboards/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn me_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/me").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

/// **`/api/v1/me`** does not require a Postgres pool: without **`DATABASE_URL`** it still returns **200** with default **`plan_tier`** (differs from most authenticated routes that return **503** `database_error`).
#[tokio::test]
async fn me_ok_without_pool_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/me", &token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["plan_tier"], "free");
    assert!(
        v["sub"].as_str().is_some_and(|s| !s.is_empty()),
        "expected sub in me response"
    );
    assert!(
        v["daily_job_quota"].as_i64().is_some_and(|n| n > 0),
        "expected positive daily_job_quota without pool"
    );
    assert!(
        v["jobs_today"].is_null(),
        "jobs_today should be absent without pool"
    );
    assert!(
        v["subscription_status"].is_null(),
        "subscription_status should be absent without pool"
    );
    assert!(
        v["subscription_current_period_end_at"].is_null(),
        "subscription_current_period_end_at should be absent without pool"
    );
}
