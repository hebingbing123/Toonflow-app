use super::super::*;
use tower::ServiceExt;

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
