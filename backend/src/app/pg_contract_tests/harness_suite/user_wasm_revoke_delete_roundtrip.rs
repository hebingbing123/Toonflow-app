use super::super::*;

use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::{header, Method, Request, StatusCode};
use sha2::{Digest, Sha256};
use uuid::Uuid;

use crate::harness::wasm_runtime;

const USER_WASM_STORE_URI: &str = "/api/v1/harness/user-wasm";

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn harness_user_wasm_revoke_soft_delete_and_list_filters_revoked() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());

    let app = build_router(contract_state(pool.clone(), secret));

    let probe = wasm_runtime::probe_wasm_bytes().to_vec();
    let probe_digest = Sha256::digest(&probe);

    // Cleanup: only remove rows created by this probe.
    // (Most pg contract suites don't touch this table yet.)
    let _ = sqlx::query(
        "DELETE FROM public.app_harness_user_wasm WHERE owner_user_id = $1 AND wasm_sha256 = $2",
    )
    .bind(sub)
    .bind(probe_digest.as_slice())
    .execute(&pool)
    .await;

    // Auth required
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(USER_WASM_STORE_URI)
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["code"], "unauthorized");

    // DELETE requires bearer too (id doesn't matter for this contract check).
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("{USER_WASM_STORE_URI}/{}", Uuid::new_v4()))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["code"], "unauthorized");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("{USER_WASM_STORE_URI}/{}", Uuid::new_v4()))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(body["code"], "not_found");

    // Persist
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(USER_WASM_STORE_URI)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/wasm")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(probe.clone()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "created={created}");
    let wasm_row_id = Uuid::parse_str(created["id"].as_str().expect("id")).unwrap();

    // List should include it (active only)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(USER_WASM_STORE_URI)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list={list}");
    assert_eq!(
        list["items"].as_array().unwrap().len(),
        1,
        "active list must include the newly persisted row"
    );

    // Revoke
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("{USER_WASM_STORE_URI}/{wasm_row_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, revoked) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "revoked={revoked}");
    assert_eq!(revoked["id"], created["id"]);
    assert!(
        revoked.get("revoked_at").is_some() && !revoked["revoked_at"].is_null(),
        "revoked_at must be present"
    );

    // List should hide revoked rows
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(USER_WASM_STORE_URI)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_after) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        list_after["items"].as_array().unwrap().len(),
        0,
        "revoked rows must not be returned by list"
    );
}
