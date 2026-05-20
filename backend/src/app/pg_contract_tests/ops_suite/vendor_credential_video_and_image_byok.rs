use super::super::*;
use tower::ServiceExt;

use crate::projects::model_routing::credentials::build_llm_config_for_model;
use crate::vendor::catalog::VendorProtocol;
use crate::vendor::video::credentials::load_video_provider_api_key;
use crate::vendor::video::VideoProvider;

/// Stored Settings credentials must decrypt and feed video + image routing (BYOK).
#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET + OPENFLOW_VENDOR_CREDENTIAL_KEY; cargo test pg_contract_tests -- --ignored"]
async fn vendor_credential_video_and_image_byok() {
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
    ensure_contract_auth_user(&pool).await;
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let state = contract_state(pool.clone(), secret);
    let app = build_router(state.clone());

    std::env::set_var(
        "OPENFLOW_VENDOR_CREDENTIAL_KEY",
        "test-encryption-key-for-contract-tests",
    );

    let doubao_key = "sk-contract-doubao-video-byok";
    let seedream_key = "sk-contract-seedream-image-byok";

    for (vendor_id, api_key) in [("20", doubao_key), ("18", seedream_key)] {
        let store_body = format!(r#"{{"vendorId":"{vendor_id}","apiKey":"{api_key}"}}"#);
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
        let (status, _) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "store vendor {vendor_id}");
    }

    let loaded_video = load_video_provider_api_key(
        &pool,
        sub,
        VideoProvider::Doubao,
        Some("20:doubao-seedance-1-0-pro"),
    )
    .await
    .expect("load video key");
    assert_eq!(loaded_video.as_deref(), Some(doubao_key));

    let cfg = build_llm_config_for_model(
        &state,
        &pool,
        sub,
        "18:doubao-seedream-3-0-t2i",
    )
    .await
    .expect("image llm config");
    assert_eq!(cfg.api_key, seedream_key);
    assert_eq!(cfg.protocol, VendorProtocol::VolcengineArk);
    assert!(cfg.base_url.contains("volces.com"));

    let _ = sqlx::query(
        "DELETE FROM public.app_vendor_credential WHERE owner_user_id = $1 AND vendor_id IN ('18', '20')",
    )
    .bind(sub)
    .execute(&pool)
    .await;

    std::env::remove_var("OPENFLOW_VENDOR_CREDENTIAL_KEY");
}
