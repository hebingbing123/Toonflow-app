use super::super::*;
use tower::ServiceExt;

/// promotion-gate/evaluate: 守卫样本退化 → 验证 blocked
#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn promotion_gate_evaluate_blocked_on_guard_failure() {
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
    let run_id = Uuid::new_v4();
    let variant_id = Uuid::new_v4();

    // 提交一个 gate decision（blocked）
    let res = app.clone().oneshot(
        Request::builder()
            .method(Method::POST)
            .uri(&format!("/api/v1/benchmark/promotion-gate/{run_id}/decide"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(format!(
                r#"{{"variantId":"{variant_id}","decision":"blocked","rationaleNote":"guard sample degraded"}}"#
            )))
            .unwrap(),
    ).await.unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "decide={body}");

    // 查询 gate summary，验证 blocked 状态存在
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(&format!("/api/v1/benchmark/promotion-gate/{run_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, summary) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "summary={summary}");
    let decisions = summary["latestDecisions"]
        .as_array()
        .expect("decisions array");
    assert!(
        decisions
            .iter()
            .any(|d| d["decision"].as_str() == Some("blocked")),
        "should have a blocked decision"
    );
}
