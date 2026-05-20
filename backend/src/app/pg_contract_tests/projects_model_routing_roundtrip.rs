use super::*;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; cargo test pg_contract_tests -- --ignored"]
async fn projects_model_routing_roundtrip() {
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
    let app = build_router(contract_state(pool.clone(), secret));

    let create_body = format!(
        r#"{{
            "name":"pg_model_routing_{}",
            "textModel":"1:gpt-4.1-mini",
            "multimodalModel":"1:gpt-4o",
            "videoModel":"1:veo-3.1-generate-preview"
        }}"#,
        Uuid::new_v4().simple()
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(create_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "create: {created:?}");
    let project_id = created["id"].as_str().expect("project id");

    let patch_body = r#"{
        "steps": {
            "script": { "text": "1:gpt-4o-mini" },
            "video": { "multimodal": "1:gpt-4o", "video": "1:veo-3.1-generate-preview" }
        }
    }"#;
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/projects/{project_id}/model-routing"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(patch_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patch routing: {patched:?}");
    assert_eq!(
        patched["steps"]["script"]["text"].as_str(),
        Some("1:gpt-4o-mini")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/projects/{project_id}/model-routing"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, got) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get routing: {got:?}");
    let effective = got["effective"].as_array().expect("effective array");
    assert!(!effective.is_empty());

    let resolve_body = r#"{"step":"script","slot":"text"}"#;
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_id}/model-routing/resolve"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(resolve_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, resolved) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "resolve: {resolved:?}");
    assert_eq!(resolved["model_id"].as_str(), Some("1:gpt-4o-mini"));
    assert_eq!(resolved["source"].as_str(), Some("step_override"));
}
