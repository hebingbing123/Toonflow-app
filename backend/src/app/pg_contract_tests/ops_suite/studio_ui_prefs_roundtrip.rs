//! Studio UI prefs — pinned projects roundtrip.

use super::super::*;
use serde_json::json;
use tower::ServiceExt;
use uuid::Uuid;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET; cargo test studio_ui_prefs_roundtrip -- --ignored"]
async fn studio_ui_prefs_roundtrip() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");
    ensure_contract_auth_user(&pool).await;

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool, secret));

    let project_id = Uuid::new_v4().to_string();
    let body = json!({ "pinnedProjectIds": [project_id] });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PUT)
                .uri("/api/v1/settings/studio-ui/prefs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, saved) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "put prefs: {saved:?}");
    let ids = saved["pinnedProjectIds"].as_array().expect("pinned ids");
    assert_eq!(ids.len(), 1);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/settings/studio-ui/prefs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, loaded) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get prefs: {loaded:?}");
    assert_eq!(
        loaded["pinnedProjectIds"].as_array().map(|a| a.len()),
        Some(1)
    );
}
