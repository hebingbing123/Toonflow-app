//! `GET /api/v1/billing/plans` and mock checkout completion roundtrip.

use super::super::*;
use axum::http::Method;
use tower::ServiceExt;

const CHECKOUT_USER: &str = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET; cargo test pg_contract_tests -- --ignored"]
async fn billing_plans_and_mock_checkout_roundtrip() {
    let _ = dotenvy::dotenv();
    std::env::set_var("BILLING_CHECKOUT_MOCK", "1");
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL");
    let secret = std::env::var("SUPABASE_JWT_SECRET").expect("SUPABASE_JWT_SECRET");
    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect");
    let sub = Uuid::parse_str(CHECKOUT_USER).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    sqlx::query(
        r#"
        INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
        VALUES ($1, 'billing-checkout@example.com', 'contract-test-password', NOW(), NOW(), NOW())
        ON CONFLICT (id) DO NOTHING
        "#,
    )
    .bind(sub)
    .execute(&pool)
    .await
    .expect("user");
    sqlx::query(
        r#"
        INSERT INTO app_user_profile (user_id, email, plan_tier, daily_job_quota)
        VALUES ($1, 'billing-checkout@example.com', 'free', 20)
        ON CONFLICT (user_id) DO UPDATE SET plan_tier = 'free', daily_job_quota = 20
        "#,
    )
    .bind(sub)
    .execute(&pool)
    .await
    .expect("profile");

    let plans_res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/billing/plans?currency=CNY")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (plans_status, plans_body) = read_json_response(plans_res).await;
    assert_eq!(plans_status, StatusCode::OK);
    assert!(plans_body["plans"].as_array().unwrap().len() >= 3);

    let checkout_res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/billing/checkout")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"plan_tier":"creator","provider":"alipay","currency":"CNY"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (checkout_status, checkout) = read_json_response(checkout_res).await;
    assert_eq!(checkout_status, StatusCode::OK);
    let session_id = checkout["session_id"].as_str().unwrap();

    let mock_res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/billing/checkout/{session_id}/mock-pay"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (mock_status, _) = read_json_response(mock_res).await;
    assert_eq!(mock_status, StatusCode::OK);

    let poll_res = app
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/billing/checkout/{session_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (poll_status, poll) = read_json_response(poll_res).await;
    assert_eq!(poll_status, StatusCode::OK);
    assert_eq!(poll["status"], "paid");

    let tier: (String,) =
        sqlx::query_as(r#"SELECT plan_tier FROM app_user_profile WHERE user_id = $1"#)
            .bind(sub)
            .fetch_one(&pool)
            .await
            .expect("profile tier");
    assert_eq!(tier.0, "creator");

    std::env::remove_var("BILLING_CHECKOUT_MOCK");
}
