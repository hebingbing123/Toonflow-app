use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test settings_agent_deploy_roundtrip -- --ignored"]
async fn settings_agent_deploy_roundtrip() {
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

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/agent-deploy/list")
                .method(Method::POST)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, before) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "before={before}");
    assert_eq!(before[0]["key"].as_str(), Some("scriptAgent"));
    assert_eq!(before[0]["model"].as_str(), Some(""));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/agent-deploy/deploy-model")
                .method(Method::POST)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"id":1,"name":"剧本Agent","model":"gpt-4.1","modelName":"GPT-4.1","vendorId":"openai","desc":"probe"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, saved) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "saved={saved}");
    assert_eq!(saved["key"].as_str(), Some("scriptAgent"));
    assert_eq!(saved["message"].as_str(), Some("保存成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/agent-deploy/list")
                .method(Method::POST)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, after) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "after={after}");
    assert_eq!(after[0]["model"].as_str(), Some("gpt-4.1"));
    assert_eq!(after[0]["modelName"].as_str(), Some("GPT-4.1"));
    assert_eq!(after[0]["vendorId"].as_str(), Some("openai"));

    let stored: Option<Value> = sqlx::query_scalar(
        r#"
        SELECT agent_deploy_config
        FROM public.app_user_profile
        WHERE user_id = $1
        "#,
    )
    .bind(sub)
    .fetch_optional(&pool)
    .await
    .expect("select agent_deploy_config");
    let stored = stored.expect("stored agent_deploy_config");
    assert_eq!(
        stored["rows"]["scriptAgent"]["model"].as_str(),
        Some("gpt-4.1")
    );

    let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}
