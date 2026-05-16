use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn settings_vendor_model_test_enqueue() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool, secret));

    let body = r#"{"modelName":"pg_vendor_mt","type":"text","id":"probe-id"}"#;
    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/model-test")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "model-test body={job}");
    assert_eq!(
        job["kind"].as_str(),
        Some(JOB_KIND_SETTINGS_VENDOR_MODEL_TEST)
    );
    assert_eq!(job["status"].as_str(), Some("queued"));
}
