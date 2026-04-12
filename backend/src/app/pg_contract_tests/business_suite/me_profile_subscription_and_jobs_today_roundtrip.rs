use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn me_profile_subscription_and_jobs_today_roundtrip() {
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
    let mut created_job_ids: Vec<Uuid> = Vec::new();

    let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;

    let period_end = chrono::DateTime::parse_from_rfc3339("2026-05-01T00:00:00Z")
        .unwrap()
        .with_timezone(&chrono::Utc);

    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (
          user_id,
          plan_tier,
          billing_currency,
          billing_provider,
          subscription_status,
          subscription_current_period_end_at,
          daily_job_quota
        )
        VALUES ($1, 'pro', 'USD', 'stripe', 'active', $2, 321)
        ON CONFLICT (user_id) DO UPDATE
        SET
          plan_tier = EXCLUDED.plan_tier,
          billing_currency = EXCLUDED.billing_currency,
          billing_provider = EXCLUDED.billing_provider,
          subscription_status = EXCLUDED.subscription_status,
          subscription_current_period_end_at = EXCLUDED.subscription_current_period_end_at,
          daily_job_quota = EXCLUDED.daily_job_quota,
          updated_at = NOW()
        "#,
    )
    .bind(sub)
    .bind(period_end)
    .execute(&pool)
    .await
    .expect("upsert app_user_profile");

    for i in 0..2 {
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/jobs")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .header("Idempotency-Key", format!("pg-me-roundtrip-{i}-{}", Uuid::new_v4()))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"kind":"{JOB_KIND_ASSET_GENERATE_IMAGE}","payload":{{"reason":"pg_me_roundtrip_{i}"}}}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created_job) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "created_job={created_job}");
        created_job_ids.push(
            Uuid::parse_str(created_job["id"].as_str().expect("job id")).expect("parse job id"),
        );
    }

    let res = app
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
    let (status, me) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "me={me}");
    assert_eq!(me["plan_tier"].as_str(), Some("pro"));
    assert_eq!(me["billing_currency"].as_str(), Some("USD"));
    assert_eq!(me["billing_provider"].as_str(), Some("stripe"));
    assert_eq!(me["subscription_status"].as_str(), Some("active"));
    assert_eq!(
        me["subscription_current_period_end_at"].as_str(),
        Some("2026-05-01T00:00:00Z")
    );
    assert_eq!(me["daily_job_quota"].as_i64(), Some(321));
    assert!(
        me["jobs_today"].as_i64().unwrap_or_default() >= 2,
        "jobs_today should include the two enqueued jobs: {me}"
    );

    cleanup_jobs(&pool, &created_job_ids).await;
    let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}
