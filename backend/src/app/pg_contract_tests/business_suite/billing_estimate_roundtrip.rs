//! `POST /api/v1/billing/estimate` roundtrip with quota enrichment and BYOK.

use super::super::*;
use axum::http::Method;
use tower::ServiceExt;

const ESTIMATE_USER: &str = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET; cargo test pg_contract_tests -- --ignored"]
async fn billing_estimate_ok_with_quota_fields() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL");
    let secret = std::env::var("SUPABASE_JWT_SECRET").expect("SUPABASE_JWT_SECRET");
    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect");
    let sub = Uuid::parse_str(ESTIMATE_USER).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    sqlx::query(
        r#"
        INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
        VALUES ($1, 'billing-estimate@example.com', 'contract-test-password', NOW(), NOW(), NOW())
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
        VALUES ($1, 'billing-estimate@example.com', 'free', 20)
        ON CONFLICT (user_id) DO UPDATE SET plan_tier = 'free', daily_job_quota = 20
        "#,
    )
    .bind(sub)
    .execute(&pool)
    .await
    .expect("profile");

    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/billing/estimate")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"model_id":"1:gpt-4o-mini","task_kind":"text_completion","quantity":2}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, value) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(value["credits"], 2);
    assert!(value["jobs_today"].is_number());
    assert_eq!(value["daily_job_quota"], 20);
    assert!(value["quota_usage_percent_after"].is_number());
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET; cargo test pg_contract_tests -- --ignored"]
async fn billing_estimate_byok_when_vendor_credential_stored() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL");
    let secret = std::env::var("SUPABASE_JWT_SECRET").expect("SUPABASE_JWT_SECRET");
    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect");
    let sub = Uuid::parse_str(ESTIMATE_USER).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    ensure_contract_auth_user(&pool).await;
    sqlx::query(
        r#"
        INSERT INTO app_vendor_credential (owner_user_id, vendor_id, api_key_encrypted, key_hint)
        VALUES ($1, '1', '\x01'::bytea, 'sk-***')
        ON CONFLICT (owner_user_id, vendor_id) DO UPDATE
        SET api_key_encrypted = EXCLUDED.api_key_encrypted
        "#,
    )
    .bind(sub)
    .execute(&pool)
    .await
    .expect("credential");

    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/billing/estimate")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"model_id":"1:gpt-4o-mini","task_kind":"asset_image_batch","quantity":1}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, value) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(value["platform_billing_exempt"], true);

    let _ = sqlx::query(
        "DELETE FROM app_vendor_credential WHERE owner_user_id = $1 AND vendor_id = '1'",
    )
    .bind(sub)
    .execute(&pool)
    .await;
}
