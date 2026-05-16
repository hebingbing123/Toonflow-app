use super::super::*;
use tower::ServiceExt;

/// bad-case-stats roundtrip: 写入 3 条 bad case → 查询 → 验证 top-1
#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn bad_case_stats_roundtrip() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL");
    let secret = std::env::var("SUPABASE_JWT_SECRET").expect("SUPABASE_JWT_SECRET");
    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect");
    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    // 写入 3 条 bad case（同一 category）
    for _ in 0..3 {
        let res = app.clone().oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/quality/reviews")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"targetType":"storyboard","isBadCase":true,"badCaseCategory":"dialogue_issue","overallScore":3,"passed":false}"#))
                .unwrap(),
        ).await.unwrap();
        assert_eq!(res.status(), StatusCode::OK);
    }

    // 查询 bad-case-stats
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/quality/bad-case-stats?limit=5")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "body={body}");
    let items = body.as_array().expect("array");
    assert!(!items.is_empty(), "should have at least one bad case stat");
    // top-1 应该是 dialogue_issue
    let top = &items[0];
    assert_eq!(
        top["badCaseCategory"].as_str().unwrap_or(""),
        "dialogue_issue"
    );
    assert!(top["count"].as_i64().unwrap_or(0) >= 3);
}
