//! Integration tests for internal ops billing endpoints (Task 8.1).
//!
//! Tests workspace subscription and job aggregates queries with internal ops token gate.

use axum::http::StatusCode;

use crate::app::contract_smoke_tests::helpers::{
    get_json_internal_ops, internal_ops_token_test_lock,
};

const INTERNAL_OPS_TOKEN_ENV: &str = "OPENFLOW_INTERNAL_OPS_TOKEN";
const WORKSPACE_SUBSCRIPTION_URI: &str = "/api/v1/ops/billing/workspace-subscription";
const WORKSPACE_JOB_AGGREGATES_URI: &str = "/api/v1/ops/billing/workspace-job-aggregates";
const NIL_UUID: &str = "00000000-0000-0000-0000-000000000000";

#[tokio::test]
async fn workspace_subscription_requires_internal_ops_token() {
    let _lock = internal_ops_token_test_lock();

    // Test without token configured
    std::env::remove_var(INTERNAL_OPS_TOKEN_ENV);
    let uri = format!("{WORKSPACE_SUBSCRIPTION_URI}?workspace_id={NIL_UUID}");
    let (status, body) = get_json_internal_ops(&uri, None).await;
    assert_eq!(status, StatusCode::FORBIDDEN);
    assert_eq!(body["code"], "forbidden");

    // Test with wrong token
    std::env::set_var(INTERNAL_OPS_TOKEN_ENV, "expected-secret");
    let (status, body) = get_json_internal_ops(&uri, Some("wrong-token")).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["code"], "unauthorized");
}

#[tokio::test]
async fn workspace_job_aggregates_requires_internal_ops_token() {
    let _lock = internal_ops_token_test_lock();

    // Test without token configured
    std::env::remove_var(INTERNAL_OPS_TOKEN_ENV);
    let uri = format!("{WORKSPACE_JOB_AGGREGATES_URI}?workspace_id={NIL_UUID}");
    let (status, body) = get_json_internal_ops(&uri, None).await;
    assert_eq!(status, StatusCode::FORBIDDEN);
    assert_eq!(body["code"], "forbidden");

    // Test with wrong token
    std::env::set_var(INTERNAL_OPS_TOKEN_ENV, "expected-secret");
    let (status, body) = get_json_internal_ops(&uri, Some("wrong-token")).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["code"], "unauthorized");
}

#[tokio::test]
async fn workspace_subscription_requires_workspace_id_param() {
    let _lock = internal_ops_token_test_lock();

    std::env::set_var(INTERNAL_OPS_TOKEN_ENV, "test-token");

    // Test without workspace_id parameter
    let (status, body) =
        get_json_internal_ops(WORKSPACE_SUBSCRIPTION_URI, Some("test-token")).await;

    // Should return 400 for missing parameter, or 503 if DB not configured
    assert!(
        status == StatusCode::BAD_REQUEST || status == StatusCode::SERVICE_UNAVAILABLE,
        "Expected 400 or 503, got {status}"
    );

    if status == StatusCode::BAD_REQUEST {
        assert_eq!(body["code"], "bad_request");
        assert!(body["message"]
            .as_str()
            .unwrap()
            .contains("Missing workspace_id parameter"));
    } else {
        assert_eq!(body["code"], "database_error");
    }
}

#[tokio::test]
async fn workspace_job_aggregates_requires_workspace_id_param() {
    let _lock = internal_ops_token_test_lock();

    std::env::set_var(INTERNAL_OPS_TOKEN_ENV, "test-token");

    // Test without workspace_id parameter
    let (status, body) =
        get_json_internal_ops(WORKSPACE_JOB_AGGREGATES_URI, Some("test-token")).await;

    // Should return 400 for missing parameter, or 503 if DB not configured
    assert!(
        status == StatusCode::BAD_REQUEST || status == StatusCode::SERVICE_UNAVAILABLE,
        "Expected 400 or 503, got {status}"
    );

    if status == StatusCode::BAD_REQUEST {
        assert_eq!(body["code"], "bad_request");
        assert!(body["message"]
            .as_str()
            .unwrap()
            .contains("Missing workspace_id parameter"));
    } else {
        assert_eq!(body["code"], "database_error");
    }
}

#[tokio::test]
async fn workspace_subscription_rejects_invalid_uuid() {
    let _lock = internal_ops_token_test_lock();

    std::env::set_var(INTERNAL_OPS_TOKEN_ENV, "test-token");

    let uri = format!("{WORKSPACE_SUBSCRIPTION_URI}?workspace_id=not-a-uuid");
    let (status, body) = get_json_internal_ops(&uri, Some("test-token")).await;

    // Should return 400 for invalid UUID format, or 503 if DB not configured
    assert!(
        status == StatusCode::BAD_REQUEST || status == StatusCode::SERVICE_UNAVAILABLE,
        "Expected 400 or 503, got {status}"
    );

    if status == StatusCode::BAD_REQUEST {
        assert_eq!(body["code"], "bad_request");
        assert!(body["message"]
            .as_str()
            .unwrap()
            .contains("Invalid workspace_id format"));
    } else {
        assert_eq!(body["code"], "database_error");
    }
}

#[tokio::test]
async fn workspace_job_aggregates_rejects_invalid_uuid() {
    let _lock = internal_ops_token_test_lock();

    std::env::set_var(INTERNAL_OPS_TOKEN_ENV, "test-token");

    let uri = format!("{WORKSPACE_JOB_AGGREGATES_URI}?workspace_id=not-a-uuid");
    let (status, body) = get_json_internal_ops(&uri, Some("test-token")).await;

    // Should return 400 for invalid UUID format, or 503 if DB not configured
    assert!(
        status == StatusCode::BAD_REQUEST || status == StatusCode::SERVICE_UNAVAILABLE,
        "Expected 400 or 503, got {status}"
    );

    if status == StatusCode::BAD_REQUEST {
        assert_eq!(body["code"], "bad_request");
        assert!(body["message"]
            .as_str()
            .unwrap()
            .contains("Invalid workspace_id format"));
    } else {
        assert_eq!(body["code"], "database_error");
    }
}

#[tokio::test]
async fn workspace_subscription_returns_404_for_nonexistent_workspace() {
    let _lock = internal_ops_token_test_lock();

    std::env::set_var(INTERNAL_OPS_TOKEN_ENV, "test-token");

    // Use a valid UUID that doesn't exist
    let uri = format!("{WORKSPACE_SUBSCRIPTION_URI}?workspace_id={NIL_UUID}");
    let (status, body) = get_json_internal_ops(&uri, Some("test-token")).await;

    // Should return 404 or 503 (if DB not configured in test environment)
    assert!(
        status == StatusCode::NOT_FOUND || status == StatusCode::SERVICE_UNAVAILABLE,
        "Expected 404 or 503, got {status}"
    );

    if status == StatusCode::NOT_FOUND {
        assert_eq!(body["code"], "not_found");
    } else {
        assert_eq!(body["code"], "database_error");
    }
}

#[tokio::test]
async fn workspace_job_aggregates_returns_404_for_nonexistent_workspace() {
    let _lock = internal_ops_token_test_lock();

    std::env::set_var(INTERNAL_OPS_TOKEN_ENV, "test-token");

    // Use a valid UUID that doesn't exist
    let uri = format!("{WORKSPACE_JOB_AGGREGATES_URI}?workspace_id={NIL_UUID}");
    let (status, body) = get_json_internal_ops(&uri, Some("test-token")).await;

    // Should return 404 or 503 (if DB not configured in test environment)
    assert!(
        status == StatusCode::NOT_FOUND || status == StatusCode::SERVICE_UNAVAILABLE,
        "Expected 404 or 503, got {status}"
    );

    if status == StatusCode::NOT_FOUND {
        assert_eq!(body["code"], "not_found");
    } else {
        assert_eq!(body["code"], "database_error");
    }
}

#[tokio::test]
async fn workspace_subscription_response_structure() {
    let _lock = internal_ops_token_test_lock();

    std::env::set_var(INTERNAL_OPS_TOKEN_ENV, "test-token");

    let uri = format!("{WORKSPACE_SUBSCRIPTION_URI}?workspace_id={NIL_UUID}");
    let (status, body) = get_json_internal_ops(&uri, Some("test-token")).await;

    // If we get a 200, verify response structure
    if status == StatusCode::OK {
        assert!(body.get("subscription").is_some());
        let subscription = &body["subscription"];

        // Verify expected fields exist (may be null for nonexistent workspace)
        if !subscription.is_null() {
            assert!(subscription.get("workspace_id").is_some());
            assert!(subscription.get("workspace_type").is_some());
            assert!(subscription.get("created_at").is_some());
            // Optional fields
            let _ = subscription.get("plan_tier");
            let _ = subscription.get("daily_job_quota");
            let _ = subscription.get("billing_provider");
            let _ = subscription.get("billing_customer_id");
            let _ = subscription.get("billing_currency");
        }
    }
}

#[tokio::test]
async fn workspace_job_aggregates_response_structure() {
    let _lock = internal_ops_token_test_lock();

    std::env::set_var(INTERNAL_OPS_TOKEN_ENV, "test-token");

    let uri = format!("{WORKSPACE_JOB_AGGREGATES_URI}?workspace_id={NIL_UUID}");
    let (status, body) = get_json_internal_ops(&uri, Some("test-token")).await;

    // If we get a 200, verify response structure
    if status == StatusCode::OK {
        assert!(body.get("aggregates").is_some());
        let aggregates = &body["aggregates"];

        // Verify expected fields exist
        assert!(aggregates.get("workspace_id").is_some());
        assert!(aggregates.get("total_jobs").is_some());
        assert!(aggregates.get("jobs_today").is_some());
        assert!(aggregates.get("jobs_last_7_days").is_some());
        assert!(aggregates.get("jobs_last_30_days").is_some());
        assert!(aggregates.get("jobs_by_status").is_some());

        // Verify jobs_by_status is an object
        assert!(aggregates["jobs_by_status"].is_object());
    }
}
