use super::*;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn jobs_rest_roundtrip() {
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

    let mut created_job_ids = Vec::new();

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"kind":"flutter.probe","payload":{"probe":"jobs-rest","slot":"cancel"}}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cancel_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "cancel_job={cancel_job}");
    let cancel_job_id = Uuid::parse_str(cancel_job["id"].as_str().expect("cancel job id")).unwrap();
    let cancel_job_id_text = cancel_job_id.to_string();
    created_job_ids.push(cancel_job_id);
    assert_eq!(cancel_job["kind"], "flutter.probe");
    assert_eq!(cancel_job["status"], "queued");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"kind":"{JOB_KIND_ASSET_POLISH_PROMPT}","payload":{{"probe":"jobs-rest","slot":"retry"}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, retry_job_seed) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "retry_job_seed={retry_job_seed}");
    let retry_job_id =
        Uuid::parse_str(retry_job_seed["id"].as_str().expect("retry job id")).unwrap();
    let retry_job_id_text = retry_job_id.to_string();
    created_job_ids.push(retry_job_id);
    assert_eq!(retry_job_seed["kind"], JOB_KIND_ASSET_POLISH_PROMPT);
    assert_eq!(retry_job_seed["status"], "queued");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, jobs_before_cancel) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "jobs_before_cancel={jobs_before_cancel}"
    );
    let jobs_before_cancel = jobs_before_cancel.as_array().expect("jobs list");
    assert!(
        jobs_before_cancel
            .iter()
            .any(|row| row["id"].as_str() == Some(cancel_job_id_text.as_str())),
        "jobs list should include cancel job: {jobs_before_cancel:?}"
    );
    assert!(
        jobs_before_cancel
            .iter()
            .any(|row| row["id"].as_str() == Some(retry_job_id_text.as_str())),
        "jobs list should include retry job: {jobs_before_cancel:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/jobs?kind=flutter.probe&status=queued")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, filtered_queued) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "filtered_queued={filtered_queued}");
    let filtered_queued = filtered_queued.as_array().expect("filtered queued rows");
    assert!(
        filtered_queued
            .iter()
            .any(|row| row["id"].as_str() == Some(cancel_job_id_text.as_str())),
        "queued flutter jobs should include cancel target: {filtered_queued:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/jobs/kinds")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, kinds) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "kinds={kinds}");
    let kinds = kinds.as_array().expect("job kinds");
    assert!(
        kinds
            .iter()
            .any(|row| row.as_str() == Some("flutter.probe")),
        "job kinds should include flutter.probe: {kinds:?}"
    );
    assert!(
        kinds
            .iter()
            .any(|row| row.as_str() == Some(JOB_KIND_ASSET_POLISH_PROMPT)),
        "job kinds should include asset polish: {kinds:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/jobs/kinds/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, kind_summary) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "kind_summary={kind_summary}");
    let kind_summary = kind_summary.as_array().expect("job kind summaries");
    assert!(
        kind_summary.iter().any(|row| {
            row["kind"].as_str() == Some("flutter.probe")
                && row["job_count"].as_i64().unwrap_or_default() >= 1
        }),
        "kind summary should include flutter.probe: {kind_summary:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/jobs/status/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, status_summary_before_cancel) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "status_summary_before_cancel={status_summary_before_cancel}"
    );
    let status_summary_before_cancel = status_summary_before_cancel
        .as_array()
        .expect("job status summaries");
    assert!(
        status_summary_before_cancel.iter().any(|row| {
            row["status"].as_str() == Some("queued")
                && row["job_count"].as_i64().unwrap_or_default() >= 2
        }),
        "status summary should include queued jobs: {status_summary_before_cancel:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/jobs/{cancel_job_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, fetched_cancel_job) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "fetched_cancel_job={fetched_cancel_job}"
    );
    assert_eq!(fetched_cancel_job["id"], cancel_job["id"]);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/jobs/{cancel_job_id}/cancel"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cancelled_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "cancelled_job={cancelled_job}");
    assert_eq!(cancelled_job["status"], "cancelled");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/jobs?status=cancelled")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cancelled_list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "cancelled_list={cancelled_list}");
    let cancelled_list = cancelled_list.as_array().expect("cancelled job rows");
    assert!(
        cancelled_list
            .iter()
            .any(|row| row["id"].as_str() == Some(cancel_job_id_text.as_str())),
        "cancelled filter should include cancelled job: {cancelled_list:?}"
    );

    sqlx::query(
        "UPDATE public.app_generation_job SET status = 'failed', error_message = 'pg jobs retry failure', result = '{\"ok\":false}'::jsonb WHERE id = $1",
    )
    .bind(retry_job_id)
    .execute(&pool)
    .await
    .expect("mark retry seed failed");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/jobs/{retry_job_id}/retry"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, retried_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "retried_job={retried_job}");
    assert_eq!(retried_job["status"], "queued");
    assert!(retried_job["error_message"].is_null());
    assert!(retried_job["result"].is_null());

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/usage/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, usage_summary) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "usage_summary={usage_summary}");
    assert!(
        usage_summary["eventsLast24h"].as_i64().unwrap_or_default() >= 2,
        "usage summary should see created job events: {usage_summary}"
    );
    assert!(
        usage_summary["eventCountsLast7d"]["generation_job.created"]
            .as_i64()
            .unwrap_or_default()
            >= 2,
        "usage summary should include generation_job.created count: {usage_summary}"
    );

    cleanup_jobs(&pool, &created_job_ids).await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn billing_webhook_events_roundtrip() {
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

    let base = Uuid::new_v4().simple().to_string();
    let stripe_info_id = format!("stripe:evt_pg_{base}_info");
    let stripe_failed_id = format!("stripe:evt_pg_{base}_failed");
    let alipay_info_id = format!("alipay:evt_pg_{base}_ali");
    let stripe_info_raw_id = format!("evt_pg_{base}_info");
    let stripe_failed_raw_id = format!("evt_pg_{base}_failed");
    let alipay_raw_id = format!("evt_pg_{base}_ali");
    let created_ids = vec![
        stripe_info_id.clone(),
        stripe_failed_id.clone(),
        alipay_info_id.clone(),
    ];

    cleanup_billing_webhook_events(&pool, &created_ids).await;

    let stripe_info_created = chrono::DateTime::parse_from_rfc3339("2026-04-08T12:00:00Z")
        .unwrap()
        .with_timezone(&chrono::Utc);
    let stripe_failed_created = chrono::DateTime::parse_from_rfc3339("2026-04-08T12:10:00Z")
        .unwrap()
        .with_timezone(&chrono::Utc);
    let alipay_created = chrono::DateTime::parse_from_rfc3339("2026-04-08T12:20:00Z")
        .unwrap()
        .with_timezone(&chrono::Utc);

    let stripe_info_row: (i64,) = sqlx::query_as(
        r#"
        INSERT INTO public.app_billing_webhook_event (
            provider_event_id,
            payload,
            created_at,
            provider,
            raw_event_id,
            event_type,
            event_created_at,
            is_informational_event
        ) VALUES ($1, '{}'::jsonb, $2, 'stripe', $3, 'invoice.upcoming', $4, true)
        RETURNING id
        "#,
    )
    .bind(&stripe_info_id)
    .bind(stripe_info_created)
    .bind(&stripe_info_raw_id)
    .bind(stripe_info_created)
    .fetch_one(&pool)
    .await
    .expect("insert stripe informational webhook row");

    let stripe_failed_row: (i64,) = sqlx::query_as(
        r#"
        INSERT INTO public.app_billing_webhook_event (
            provider_event_id,
            payload,
            created_at,
            provider,
            raw_event_id,
            event_type,
            event_created_at,
            is_informational_event
        ) VALUES ($1, '{}'::jsonb, $2, 'stripe', $3, 'invoice.payment_failed', $4, false)
        RETURNING id
        "#,
    )
    .bind(&stripe_failed_id)
    .bind(stripe_failed_created)
    .bind(&stripe_failed_raw_id)
    .bind(stripe_failed_created)
    .fetch_one(&pool)
    .await
    .expect("insert stripe failed webhook row");

    let _: (i64,) = sqlx::query_as(
        r#"
        INSERT INTO public.app_billing_webhook_event (
            provider_event_id,
            payload,
            created_at,
            provider,
            raw_event_id,
            event_type,
            event_created_at,
            is_informational_event
        ) VALUES ($1, '{}'::jsonb, $2, 'alipay', $3, 'trade.finished', $4, true)
        RETURNING id
        "#,
    )
    .bind(&alipay_info_id)
    .bind(alipay_created)
    .bind(&alipay_raw_id)
    .bind(alipay_created)
    .fetch_one(&pool)
    .await
    .expect("insert alipay webhook row");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/webhooks/billing/events?informational_event=true&provider=stripe&raw_event_id_prefix=evt_pg_{base}_&event_type=invoice.upcoming&provider_event_id={stripe_info_id}&provider_event_id_prefix=stripe:evt_pg_{base}_&event_created_from=2026-04-08T11:59:00Z&event_created_to=2026-04-08T12:01:00Z&created_from=2026-04-08T11:59:00Z&created_to=2026-04-08T12:01:00Z&id_min={}&id_max={}&sort=id_asc&limit=10&offset=0",
                    stripe_info_row.0,
                    stripe_info_row.0
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, filtered) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "filtered={filtered}");
    assert_eq!(filtered["total"].as_i64(), Some(1));
    assert_eq!(filtered["has_more"], false);
    assert!(filtered["next_offset"].is_null());
    let filtered_items = filtered["items"].as_array().expect("filtered items");
    assert_eq!(filtered_items.len(), 1);
    assert_eq!(
        filtered_items[0]["provider_event_id"].as_str(),
        Some(stripe_info_id.as_str())
    );
    assert_eq!(filtered_items[0]["provider"].as_str(), Some("stripe"));
    assert_eq!(
        filtered_items[0]["raw_event_id"].as_str(),
        Some(stripe_info_raw_id.as_str())
    );
    assert_eq!(
        filtered_items[0]["event_type"].as_str(),
        Some("invoice.upcoming")
    );
    assert_eq!(filtered_items[0]["is_informational_event"], true);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(
                    "/api/v1/webhooks/billing/events?provider=stripe&sort=id_desc&limit=1&offset=0",
                )
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, paged) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "paged={paged}");
    assert_eq!(paged["total"].as_i64(), Some(2));
    assert_eq!(paged["limit"].as_i64(), Some(1));
    assert_eq!(paged["offset"].as_i64(), Some(0));
    assert_eq!(paged["has_more"], true);
    assert_eq!(paged["next_offset"].as_i64(), Some(1));
    let paged_items = paged["items"].as_array().expect("paged items");
    assert_eq!(paged_items.len(), 1);
    assert_eq!(
        paged_items[0]["provider_event_id"].as_str(),
        Some(stripe_failed_id.as_str())
    );
    assert_eq!(paged_items[0]["id"].as_i64(), Some(stripe_failed_row.0));

    cleanup_billing_webhook_events(&pool, &created_ids).await;
}

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

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn promote_staging_populates_assets_and_links() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    cleanup_promote_staging_fixtures(&pool).await;

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    sqlx::query(
        r#"INSERT INTO public.legacy_user_map (legacy_user_id, supabase_user_id)
           VALUES ($1, $2)
           ON CONFLICT (legacy_user_id) DO UPDATE SET supabase_user_id = EXCLUDED.supabase_user_id"#,
    )
    .bind(PROMO_LEGACY_USER)
    .bind(sub)
    .execute(&pool)
    .await
    .expect("legacy_user_map insert (requires existing auth.users id = CONTRACT_USER_SUB)");

    let project = serde_json::json!({
        "id": PROMO_PROJECT_LEG,
        "userId": PROMO_LEGACY_USER,
        "name": "pg_promote_project",
    });
    sqlx::query(
        r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_project', 'pg_promote_proj', $1)"#,
    )
    .bind(Json(project))
    .execute(&pool)
    .await
    .expect("staging o_project");

    let script = serde_json::json!({
        "id": PROMO_SCRIPT_LEG,
        "projectId": PROMO_PROJECT_LEG,
        "name": "pg_promote_script",
    });
    sqlx::query(
        r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_script', 'pg_promote_script', $1)"#,
    )
    .bind(Json(script))
    .execute(&pool)
    .await
    .expect("staging o_script");

    let asset = serde_json::json!({
        "id": PROMO_ASSET_LEG,
        "projectId": PROMO_PROJECT_LEG,
        "name": "pg_promote_hero",
        "type": "character",
        "describe": "promoted lead",
        "imageId": PROMO_IMAGE_LEG,
    });
    sqlx::query(
        r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_assets', 'pg_promote_asset', $1)"#,
    )
    .bind(Json(asset))
    .execute(&pool)
    .await
    .expect("staging o_assets");

    let link = serde_json::json!({
        "scriptId": PROMO_SCRIPT_LEG,
        "assetId": PROMO_ASSET_LEG,
    });
    sqlx::query(
        r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_scriptAssets', 'pg_promote_script_asset', $1)"#,
    )
    .bind(Json(link))
    .execute(&pool)
    .await
    .expect("staging o_scriptAssets");

    let art_style = serde_json::json!({
        "id": PROMO_ART_STYLE_LEG,
        "name": "pg_promote_style",
        "fileUrl": "/art/promo.jpg",
        "label": "pg_label",
        "prompt": "pg_prompt",
    });
    sqlx::query(
        r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_artStyle', 'pg_promote_art_style', $1)"#,
    )
    .bind(Json(art_style))
    .execute(&pool)
    .await
    .expect("staging o_artStyle");

    let o_prompt_row = serde_json::json!({
        "id": 1,
        "name": "事件提取",
        "type": "eventExtraction",
        "data": "pg_promoted_prompt_body_evt",
    });
    sqlx::query(
        r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_prompt', 'pg_promote_prompt', $1)"#,
    )
    .bind(Json(o_prompt_row))
    .execute(&pool)
    .await
    .expect("staging o_prompt");

    let o_image_row = serde_json::json!({
        "id": PROMO_IMAGE_LEG,
        "assetsId": PROMO_ASSET_LEG,
        "filePath": "/promo/history_corner.png",
        "state": "已完成",
    });
    sqlx::query(
        r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_image', 'pg_promote_image', $1)"#,
    )
    .bind(Json(o_image_row))
    .execute(&pool)
    .await
    .expect("staging o_image");

    sqlx::query("SELECT 1 FROM public.promote_legacy_from_staging() LIMIT 1")
        .execute(&pool)
        .await
        .expect("promote_legacy_from_staging");

    let asset_rows: i64 =
        sqlx::query_scalar("SELECT COUNT(*)::bigint FROM public.app_asset WHERE legacy_id = $1")
            .bind(PROMO_ASSET_LEG)
            .fetch_one(&pool)
            .await
            .expect("count app_asset");
    assert_eq!(asset_rows, 1, "expected one promoted app_asset row");

    let link_rows: i64 = sqlx::query_scalar(
        r#"SELECT COUNT(*)::bigint FROM public.app_script_asset sa
           INNER JOIN public.app_script sc ON sc.id = sa.script_id
           INNER JOIN public.app_asset a ON a.id = sa.asset_id
           WHERE sc.legacy_id = $1 AND a.legacy_id = $2"#,
    )
    .bind(PROMO_SCRIPT_LEG)
    .bind(PROMO_ASSET_LEG)
    .fetch_one(&pool)
    .await
    .expect("count script_asset link");
    assert_eq!(link_rows, 1, "expected one promoted app_script_asset row");

    let promoted_img: i64 = sqlx::query_scalar(
        "SELECT COUNT(*)::bigint FROM public.app_asset_image WHERE legacy_image_id = $1",
    )
    .bind(PROMO_IMAGE_LEG)
    .fetch_one(&pool)
    .await
    .expect("count app_asset_image by legacy_image_id");
    assert_eq!(promoted_img, 1, "expected one promoted app_asset_image row");

    let style_rows: i64 = sqlx::query_scalar(
        "SELECT COUNT(*)::bigint FROM public.app_art_style WHERE legacy_id = $1",
    )
    .bind(PROMO_ART_STYLE_LEG)
    .fetch_one(&pool)
    .await
    .expect("count app_art_style");
    assert_eq!(style_rows, 1, "expected one promoted app_art_style row");

    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let promo_project_uuid: Uuid = sqlx::query_scalar(
        r#"SELECT id FROM public.app_project WHERE legacy_id = $1 AND owner_user_id = $2"#,
    )
    .bind(PROMO_PROJECT_LEG)
    .bind(sub)
    .fetch_one(&pool)
    .await
    .expect("promoted project pk");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/art-styles")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, styles_body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "art_styles={styles_body}");
    let sitems = styles_body["items"].as_array().expect("style items");
    let sfound = sitems
        .iter()
        .find(|row| row["legacy_id"].as_i64() == Some(i64::from(PROMO_ART_STYLE_LEG)));
    let srow = sfound.expect("promoted art style in list");
    assert_eq!(srow["name"].as_str(), Some("pg_promote_style"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/projects/{}/assets", promo_project_uuid))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "assets list={list}");
    let items = list["items"].as_array().expect("items");
    let found = items
        .iter()
        .find(|row| row["legacy_id"].as_i64() == Some(i64::from(PROMO_ASSET_LEG)));
    let row = found.expect("promoted asset in list");
    assert_eq!(row["name"].as_str(), Some("pg_promote_hero"));
    assert_eq!(row["asset_type"].as_str(), Some("role"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{}/assets?script_legacy_id={}",
                    promo_project_uuid, PROMO_SCRIPT_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, linked) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "linked={linked}");
    assert_eq!(linked["total"], 1);
    assert_eq!(
        linked["items"][0]["legacy_id"].as_i64(),
        Some(i64::from(PROMO_ASSET_LEG))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{}/assets/corner-scape",
                    promo_project_uuid
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, corner) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "corner={corner}");
    let citems = corner["items"].as_array().expect("corner items");
    let hero = citems
        .iter()
        .find(|row| row["legacy_id"].as_i64() == Some(i64::from(PROMO_ASSET_LEG)))
        .expect("promoted asset in corner-scape");
    let hist = hero["history_images"].as_array().expect("history_images");
    assert_eq!(hist.len(), 1);
    assert_eq!(
        hist[0]["file_path"].as_str(),
        Some("/promo/history_corner.png")
    );
    assert_eq!(hist[0]["state"].as_str(), Some("已完成"));
    assert_eq!(
        hist[0]["legacy_image_id"].as_i64(),
        Some(i64::from(PROMO_IMAGE_LEG))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{}/assets/{}/images",
                    promo_project_uuid, PROMO_ASSET_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, promo_list_img) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "promo_list_img={promo_list_img}");
    assert_eq!(
        promo_list_img["cover_legacy_image_id"].as_i64(),
        Some(i64::from(PROMO_IMAGE_LEG))
    );
    let plim = promo_list_img["items"]
        .as_array()
        .expect("promoted image list items");
    assert_eq!(plim.len(), 1);
    assert_eq!(plim[0]["selected"], true);
    assert_eq!(
        plim[0]["legacy_image_id"].as_i64(),
        Some(i64::from(PROMO_IMAGE_LEG))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/projects/{}/assets/{}",
                    promo_project_uuid, PROMO_ASSET_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"cover_legacy_image_id":null}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "clear cover via PATCH");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{}/assets/{}/images",
                    promo_project_uuid, PROMO_ASSET_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cleared_list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "cleared_list={cleared_list}");
    assert!(cleared_list["cover_legacy_image_id"].is_null());
    let clim = cleared_list["items"].as_array().expect("cleared items");
    assert_eq!(clim[0]["selected"], false);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/projects/{}/assets/{}",
                    promo_project_uuid, PROMO_ASSET_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"cover_legacy_image_id":{}}}"#,
                    PROMO_IMAGE_LEG
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "restore cover via PATCH");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{}/assets/{}/images",
                    promo_project_uuid, PROMO_ASSET_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, restored_list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "restored_list={restored_list}");
    assert_eq!(
        restored_list["cover_legacy_image_id"].as_i64(),
        Some(i64::from(PROMO_IMAGE_LEG))
    );
    let rlim = restored_list["items"].as_array().expect("restored items");
    assert_eq!(rlim[0]["selected"], true);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/prompts")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, prompts_body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "prompts={prompts_body}");
    let parr = prompts_body.as_array().expect("prompts json array");
    assert_eq!(parr.len(), 3);
    let p1 = parr
        .iter()
        .find(|row| row["id"].as_i64() == Some(1))
        .expect("prompt legacy id 1");
    assert_eq!(
        p1["data"].as_str(),
        Some("pg_promoted_prompt_body_evt"),
        "promoted o_prompt body should override file default"
    );

    cleanup_promote_staging_fixtures(&pool).await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn prompts_list_patch_roundtrip() {
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
    sqlx::query("DELETE FROM public.app_user_prompt WHERE owner_user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await
        .expect("cleanup app_user_prompt");

    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/prompts")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list={list}");
    let arr = list.as_array().expect("prompts array");
    assert_eq!(arr.len(), 3);

    let patch_body = r#"{"data":"pg_contract_prompt_patch_slot_2"}"#;
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri("/api/v1/prompts/2")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(patch_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patched={patched}");
    assert_eq!(
        patched["data"].as_str(),
        Some("pg_contract_prompt_patch_slot_2")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/prompts/2")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, one) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get one={one}");
    assert_eq!(one["id"].as_i64(), Some(2));
    assert_eq!(
        one["data"].as_str(),
        Some("pg_contract_prompt_patch_slot_2")
    );

    let res = app
        .oneshot(
            Request::builder()
                .uri("/api/v1/prompts")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, again) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "again={again}");
    let p2 = again
        .as_array()
        .expect("array")
        .iter()
        .find(|row| row["id"].as_i64() == Some(2))
        .expect("id 2");
    assert_eq!(p2["data"].as_str(), Some("pg_contract_prompt_patch_slot_2"));

    let _ = sqlx::query("DELETE FROM public.app_user_prompt WHERE owner_user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn art_styles_crud_roundtrip() {
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
                .method(Method::POST)
                .uri("/api/v1/art-styles")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"name":"pg_contract_art_style","prompt":"pg_contract_prompt"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "created={created}");
    let leg = created["legacy_id"].as_i64().expect("legacy_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/art-styles")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list={list}");
    assert!(list["total"].as_i64().unwrap_or(0) >= 1);
    let items = list["items"].as_array().expect("items");
    assert!(items
        .iter()
        .any(|row| row["legacy_id"].as_i64() == Some(i64::from(leg))));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/art-styles/numeric/{leg}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, one) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "one={one}");
    assert_eq!(one["name"].as_str(), Some("pg_contract_art_style"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/art-styles/numeric/{leg}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"label":"pg_contract_label"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patched={patched}");
    assert_eq!(patched["label"].as_str(), Some("pg_contract_label"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/art-styles/numeric/{leg}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), StatusCode::NO_CONTENT);

    let res = app
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/art-styles/numeric/{leg}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, gone) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NOT_FOUND, "gone={gone}");
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn art_styles_base64_cover_roundtrip() {
    use serde_json::json;

    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let tmp = tempfile::tempdir().expect("tempdir");
    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state_with_local_art_style_dir(
        pool.clone(),
        secret.clone(),
        tmp.path().to_path_buf(),
    ));

    let cover =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/art-styles")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "name": "pg_contract_art_style_cover",
                        "file_url": cover,
                        "prompt": "cover prompt"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "created={created}");
    let legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;
    let cover_uri = format!("/api/v1/art-styles/numeric/{legacy_id}/cover");
    assert_eq!(created["file_url"].as_str(), Some(cover_uri.as_str()));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(&cover_uri)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, bytes, ct) = read_bytes_response(res, 64 * 1024).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(ct.as_deref(), Some("image/png"));
    assert!(!bytes.is_empty(), "cover bytes should be non-empty");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/art-styles/numeric/{legacy_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"file_url":null}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patched={patched}");
    assert!(patched["file_url"].is_null());

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(&cover_uri)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, missing) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NOT_FOUND, "missing={missing}");

    let _ = sqlx::query("DELETE FROM public.app_art_style WHERE owner_user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn vendor_config_enable_update_roundtrip() {
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

    // Get vendors summary (initially no user config)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/vendors/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, summary) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "summary={summary}");
    assert_eq!(
        summary["source"].as_str(),
        Some("static_catalog_with_user_config")
    );
    let vendors = summary["vendors"].as_array().expect("vendors array");
    assert!(!vendors.is_empty());
    let first_vendor_id = vendors[0]["id"].as_i64().expect("vendor id") as i32;
    let first_vendor_id_str = format!("{}", first_vendor_id);

    // Initially no userConfig present
    assert!(vendors[0]["userConfig"].is_null() || vendors[0]["userConfig"].is_object());

    // Enable vendor
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/enable")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"id":"{}","enable":1}}"#,
                    first_vendor_id_str
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, enabled) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "enabled={enabled}");
    assert_eq!(
        enabled["vendorId"].as_str(),
        Some(first_vendor_id_str.as_str())
    );
    assert_eq!(enabled["enabled"].as_bool(), Some(true));

    // Verify summary shows enabled vendor with userConfig
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/vendors/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, summary2) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "summary2={summary2}");
    let vendors2 = summary2["vendors"].as_array().expect("vendors array");
    let v0 = vendors2
        .iter()
        .find(|v| v["id"].as_i64() == Some(i64::from(first_vendor_id)))
        .expect("vendor in summary2");
    assert_eq!(
        v0["userConfig"]["vendorId"].as_str(),
        Some(first_vendor_id_str.as_str())
    );
    assert_eq!(v0["userConfig"]["enabled"].as_bool(), Some(true));

    // Update vendor with display name and model selection
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/update")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"id":"{}","displayName":"My Vendor","selectedModels":["gpt-4o-mini"],"settings":{{"timeout":"30"}}}}"#,
                    first_vendor_id_str
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, updated) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "updated={updated}");
    assert_eq!(
        updated["vendorId"].as_str(),
        Some(first_vendor_id_str.as_str())
    );

    // Verify summary shows updated config
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/vendors/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, summary3) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "summary3={summary3}");
    let vendors3 = summary3["vendors"].as_array().expect("vendors array");
    let v0_3 = vendors3
        .iter()
        .find(|v| v["id"].as_i64() == Some(i64::from(first_vendor_id)))
        .expect("vendor");
    assert_eq!(
        v0_3["userConfig"]["displayName"].as_str(),
        Some("My Vendor")
    );
    let models = v0_3["userConfig"]["selectedModels"]
        .as_array()
        .expect("selectedModels");
    assert!(models.iter().any(|m| m.as_str() == Some("gpt-4o-mini")));
    assert_eq!(
        v0_3["userConfig"]["settings"]["timeout"].as_str(),
        Some("30")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/add")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"tsCode":"export default { id: 'probe' }"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, added) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "added={added}");
    let custom_vendor_id = added["vendorId"]
        .as_str()
        .expect("custom vendor id")
        .to_string();
    assert!(custom_vendor_id.starts_with("custom-"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/update-code")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"id":"{custom_vendor_id}","tsCode":"export default {{ updated: true }}"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, updated_code) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "updated_code={updated_code}");
    assert_eq!(
        updated_code["vendorId"].as_str(),
        Some(custom_vendor_id.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/vendors/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, summary4) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "summary4={summary4}");
    let vendors4 = summary4["vendors"].as_array().expect("vendors array");
    assert!(vendors4
        .iter()
        .any(|v| v["userConfig"]["vendorId"].as_str() == Some(custom_vendor_id.as_str())));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/code-from-link")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"link":"https://example.com/vendor.ts"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, linked) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "linked={linked}");
    let linked_vendor_id = linked["vendorId"]
        .as_str()
        .expect("linked vendor id")
        .to_string();
    assert!(linked_vendor_id.starts_with("linked-"));
    assert_eq!(
        linked["link"].as_str(),
        Some("https://example.com/vendor.ts")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/delete")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":"{custom_vendor_id}"}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, deleted) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "deleted={deleted}");
    assert_eq!(
        deleted["vendorId"].as_str(),
        Some(custom_vendor_id.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/delete")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":"{linked_vendor_id}"}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, deleted_linked) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "deleted_linked={deleted_linked}");
    assert_eq!(
        deleted_linked["vendorId"].as_str(),
        Some(linked_vendor_id.as_str())
    );

    // Disable vendor
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/enable")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"id":"{}","enable":0}}"#,
                    first_vendor_id_str
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, disabled) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "disabled={disabled}");
    assert_eq!(disabled["enabled"].as_bool(), Some(false));

    // Cleanup
    let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}
