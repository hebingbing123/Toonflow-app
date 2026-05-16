use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
async fn vendor_credential_store_get_delete_roundtrip() {
    let _guard = vendor_credential_test_lock().await;
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

    // Set encryption key for test
    std::env::set_var(
        "TOONFLOW_VENDOR_CREDENTIAL_KEY",
        "test-encryption-key-for-contract-tests",
    );

    let vendor_id = "openai";

    // Store credential
    let store_body = format!(
        r#"{{"vendorId":"{}","apiKey":"sk-test1234567890","apiSecret":"secret123","apiToken":"token123"}}"#,
        vendor_id
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/credential")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(store_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, stored) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "store credential={stored}");
    assert_eq!(stored["vendorId"].as_str(), Some(vendor_id));
    assert_eq!(stored["keyHint"].as_str(), Some("...7890"));
    assert_eq!(stored["hasSecret"].as_bool(), Some(true));
    assert_eq!(stored["hasToken"].as_bool(), Some(true));
    assert_eq!(
        stored["message"].as_str(),
        Some("Credential stored securely")
    );

    // Get credential metadata
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/settings/vendors/credential/{}", vendor_id))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, got) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get credential={got}");
    assert_eq!(got["vendorId"].as_str(), Some(vendor_id));
    assert_eq!(got["keyHint"].as_str(), Some("...7890"));
    assert_eq!(got["hasSecret"].as_bool(), Some(true));
    assert_eq!(got["hasToken"].as_bool(), Some(true));

    // Delete credential
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/settings/vendors/credential/{}", vendor_id))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, deleted) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "delete credential={deleted}");
    assert_eq!(deleted["vendorId"].as_str(), Some(vendor_id));
    assert_eq!(deleted["message"].as_str(), Some("Credential deleted"));

    // Verify deletion - should get 404
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/settings/vendors/credential/{}", vendor_id))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "credential should be deleted"
    );

    // Cleanup
    let _ = sqlx::query("DELETE FROM public.app_vendor_credential WHERE owner_user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;

    // Clean up env var
    std::env::remove_var("TOONFLOW_VENDOR_CREDENTIAL_KEY");
}
