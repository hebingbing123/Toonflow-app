use super::super::*;
use tower::ServiceExt;

/// review-queue roundtrip: create → submit → 验证回写
#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn review_queue_roundtrip() {
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

    // 创建 review queue item
    let res = app.clone().oneshot(
        Request::builder()
            .method(Method::POST)
            .uri("/api/v1/benchmark/review-queue")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(format!(
                r#"{{"experimentRunId":"{run_id}","variantId":"{run_id}","caseId":"{run_id}","stage":"video_prompt","priority":1}}"#
            )))
            .unwrap(),
    ).await.unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "create={created}");
    let item_id = created["id"].as_str().expect("item id");

    // 提交 review
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(&format!("/api/v1/benchmark/review-queue/{item_id}/submit"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"submittedScore":{"overallScore":85,"passed":true,"recommendation":"approved","notes":"ok"}}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, submitted) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "submit={submitted}");
    assert_eq!(submitted["status"].as_str().unwrap_or(""), "submitted");
}
