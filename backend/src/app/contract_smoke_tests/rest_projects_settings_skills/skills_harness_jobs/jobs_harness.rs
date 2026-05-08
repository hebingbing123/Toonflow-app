use super::super::super::helpers::*;
use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::{header, Method, Request, StatusCode};
use uuid::Uuid;

use crate::harness::wasm_runtime::probe_wasm_bytes;

const VALIDATE_USER_WASM_URI: &str = "/api/v1/harness/user-wasm/validate";
const USER_WASM_STORE_URI: &str = "/api/v1/harness/user-wasm";
const NIL_UUID: &str = "00000000-0000-0000-0000-000000000000";

#[tokio::test]
async fn harness_tools_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/harness/tools").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn job_by_id_unauthorized_without_bearer() {
    let uri = format!("/api/v1/jobs/{NIL_JOB_UUID}");
    let (status, v) = get_json(&uri).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn job_cancel_unauthorized_without_bearer() {
    let uri = format!("/api/v1/jobs/{NIL_JOB_UUID}/cancel");
    let (status, v) = post_empty_no_bearer(&uri).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn job_retry_unauthorized_without_bearer() {
    let uri = format!("/api/v1/jobs/{NIL_JOB_UUID}/retry");
    let (status, v) = post_empty_no_bearer(&uri).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn harness_validate_user_wasm_unauthorized_without_bearer() {
    let wasm = probe_wasm_bytes();
    let (status, v) = oneshot_json(
        Request::builder()
            .method(Method::POST)
            .uri(VALIDATE_USER_WASM_URI)
            .header(header::CONTENT_TYPE, "application/wasm")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(wasm.to_vec()))
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn harness_validate_user_wasm_ok_for_embedded_probe() {
    let token = test_jwt(Uuid::nil());
    let wasm = probe_wasm_bytes();
    let (status, v) =
        post_bytes_bearer_octet(VALIDATE_USER_WASM_URI, &token, "application/wasm", wasm).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["validated"], true);
    assert_eq!(v["size_bytes"].as_u64(), Some(wasm.len() as u64));
}

#[tokio::test]
async fn harness_validate_user_wasm_octet_stream_accepts_probe() {
    let token = test_jwt(Uuid::nil());
    let wasm = probe_wasm_bytes();
    let (status, v) = post_bytes_bearer_octet(
        VALIDATE_USER_WASM_URI,
        &token,
        "application/octet-stream",
        wasm,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["validated"], true);
}

#[tokio::test]
async fn harness_validate_user_wasm_bad_request_empty_body() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_empty_bearer(VALIDATE_USER_WASM_URI, &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
    assert!(
        v["message"].as_str().unwrap_or_default().contains("empty"),
        "msg={:?}",
        v["message"]
    );
}

#[tokio::test]
async fn harness_validate_user_wasm_bad_request_garbage() {
    let token = test_jwt(Uuid::nil());
    let garbage = b"\0asm\x01\x00\x00\x00\xff";
    let (status, v) =
        post_bytes_bearer_octet(VALIDATE_USER_WASM_URI, &token, "application/wasm", garbage).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn harness_user_wasm_list_unauthorized_without_bearer() {
    let (status, v) = get_json(USER_WASM_STORE_URI).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn harness_user_wasm_persist_unauthorized_without_bearer() {
    let wasm = probe_wasm_bytes();
    let (status, v) = oneshot_json(
        Request::builder()
            .method(Method::POST)
            .uri(USER_WASM_STORE_URI)
            .header(header::CONTENT_TYPE, "application/wasm")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(wasm.to_vec()))
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn harness_user_wasm_list_returns_database_error_without_pg() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(USER_WASM_STORE_URI, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn harness_user_wasm_persist_returns_database_error_without_pg() {
    let token = test_jwt(Uuid::nil());
    let wasm = probe_wasm_bytes();
    let (status, v) =
        post_bytes_bearer_octet(USER_WASM_STORE_URI, &token, "application/wasm", wasm).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn harness_user_wasm_revoke_unauthorized_without_bearer() {
    let uri = format!("{USER_WASM_STORE_URI}/{NIL_UUID}");
    let (status, v) = delete_json_no_bearer(&uri).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn harness_user_wasm_revoke_rejects_non_uuid_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("{USER_WASM_STORE_URI}/not-a-uuid");
    let (status, v) = delete_json_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn harness_user_wasm_revoke_returns_database_error_without_pg() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("{USER_WASM_STORE_URI}/{NIL_UUID}");
    let (status, v) = delete_json_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
