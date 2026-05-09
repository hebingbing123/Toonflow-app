use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test settings_platform_config_guards_roundtrip -- --ignored"]
async fn settings_platform_config_guards_roundtrip() {
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
    let app = build_router(contract_state(pool, secret));

    let me_res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/me")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (me_status, me_body) = read_json_response(me_res).await;
    assert_eq!(me_status, StatusCode::OK, "me={me_body}");
    assert_eq!(
        me_body["current_workspace"]["workspace_type"].as_str(),
        Some("personal")
    );

    let forbidden_body = r#"{
      "scope":"workspace",
      "toggles":{
        "helpHubEnabled":true,
        "qualityDashboardEnabled":true,
        "qualityRefreshControlsEnabled":true,
        "workspaceActivityEnabled":true,
        "benchmarkPaneEnabled":true,
        "jobsPaneEnabled":false
      }
    }"#;
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/platform-config")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(forbidden_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, forbidden) = read_json_response(res).await;
    assert_eq!(status, StatusCode::FORBIDDEN, "forbidden={forbidden}");
    assert_eq!(forbidden["code"].as_str(), Some("forbidden"));
    assert!(
        forbidden["message"]
            .as_str()
            .unwrap_or_default()
            .contains("enterprise owner/admin"),
        "forbidden message should explain enterprise owner/admin requirement: {forbidden}"
    );

    let invalid_scope_body = r#"{
      "scope":"plan",
      "toggles":{
        "helpHubEnabled":true,
        "qualityDashboardEnabled":true,
        "qualityRefreshControlsEnabled":true,
        "workspaceActivityEnabled":true,
        "benchmarkPaneEnabled":true,
        "jobsPaneEnabled":true
      }
    }"#;
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/platform-config")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(invalid_scope_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, invalid_scope) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "invalid_scope={invalid_scope}"
    );
    assert_eq!(invalid_scope["code"].as_str(), Some("bad_request"));
    assert_eq!(
        invalid_scope["message"].as_str(),
        Some("scope must be user or workspace")
    );
}
