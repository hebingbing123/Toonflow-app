use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn quality_reviews_roundtrip() {
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

    let quality_job_id = Uuid::new_v4();
    let script_target_id = format!("pg_quality_script_{}", Uuid::new_v4());
    let asset_target_id = format!("pg_quality_asset_{}", Uuid::new_v4());
    let mut created_review_ids = Vec::new();
    let mut created_job_ids = Vec::new();

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .header("Idempotency-Key", format!("quality-review-{quality_job_id}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"kind":"flutter.probe","payload":{{"scope":"quality-review","marker":"{quality_job_id}"}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "created_job={created_job}");
    let quality_job_id = Uuid::parse_str(created_job["id"].as_str().expect("quality job id"))
        .expect("quality job uuid");
    created_job_ids.push(quality_job_id);

    sqlx::query(
        r#"
        INSERT INTO public.app_llm_usage_log (
            user_id, job_id, call_type, model_name, provider,
            prompt_tokens, completion_tokens, total_tokens,
            prompt_chars, success, duration_ms, meta
        )
        VALUES (
            $1, $2, 'jobs.asset_polish_prompt', 'gpt-4o-mini', 'openai',
            120, 80, 200, 640, true, 800, '{"seed":"quality-roundtrip"}'::jsonb
        )
        "#,
    )
    .bind(sub)
    .bind(quality_job_id)
    .execute(&pool)
    .await
    .expect("seed llm usage log");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/quality/reviews")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"targetType":"script","targetId":"{script_target_id}","jobId":"{quality_job_id}","source":"auto","overallScore":8,"passed":true,"memoryDeliveryPriorityApplied":true,"comments":"pg quality script"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created_script) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "script review={created_script}");
    assert_eq!(created_script["targetType"], "script");
    assert_eq!(
        created_script["targetId"].as_str(),
        Some(script_target_id.as_str())
    );
    assert_eq!(created_script["source"], "auto");
    assert_eq!(created_script["overallScore"], 8);
    assert_eq!(created_script["passed"], true);
    assert_eq!(created_script["memoryDeliveryPriorityApplied"], true);
    let script_review_id =
        Uuid::parse_str(created_script["id"].as_str().expect("script review id")).unwrap();
    let script_review_id_text = script_review_id.to_string();
    created_review_ids.push(script_review_id);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/quality/reviews")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"targetType":"asset","targetId":"{asset_target_id}","jobId":"{quality_job_id}","overallScore":4,"passed":false,"isBadCase":true,"badCaseCategory":"visual_error","comments":"pg quality asset"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created_asset) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "asset review={created_asset}");
    assert_eq!(created_asset["targetType"], "asset");
    assert_eq!(
        created_asset["targetId"].as_str(),
        Some(asset_target_id.as_str())
    );
    assert_eq!(created_asset["source"], "manual");
    assert_eq!(created_asset["isBadCase"], true);
    assert_eq!(created_asset["badCaseCategory"], "visual_error");
    let asset_review_id =
        Uuid::parse_str(created_asset["id"].as_str().expect("asset review id")).unwrap();
    let asset_review_id_text = asset_review_id.to_string();
    created_review_ids.push(asset_review_id);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/quality/reviews?targetType=script&targetId={script_target_id}"
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
    let filtered = filtered.as_array().expect("filtered list");
    assert_eq!(filtered.len(), 1);
    assert_eq!(
        filtered[0]["id"].as_str(),
        Some(script_review_id_text.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/quality/reviews?isBadCase=true")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, bad_cases) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "bad_cases={bad_cases}");
    let bad_cases = bad_cases.as_array().expect("bad cases list");
    assert!(
        bad_cases
            .iter()
            .any(|row| row["id"].as_str() == Some(asset_review_id_text.as_str())),
        "bad case list should include created asset review: {bad_cases:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/quality/reviews?memoryDeliveryPriorityApplied=true")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, delivery_priority_reviews) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "delivery_priority_reviews={delivery_priority_reviews}"
    );
    let delivery_priority_reviews = delivery_priority_reviews
        .as_array()
        .expect("delivery priority review list");
    assert_eq!(delivery_priority_reviews.len(), 1);
    assert_eq!(
        delivery_priority_reviews[0]["id"].as_str(),
        Some(script_review_id_text.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/quality/reviews?jobId={quality_job_id}&limit=1&offset=0"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job_page_one) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "job_page_one={job_page_one}");
    let job_page_one = job_page_one.as_array().expect("job page one");
    assert_eq!(job_page_one.len(), 1);
    assert_eq!(
        job_page_one[0]["id"].as_str(),
        Some(asset_review_id_text.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/quality/reviews?jobId={quality_job_id}&limit=1&offset=1"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job_page_two) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "job_page_two={job_page_two}");
    let job_page_two = job_page_two.as_array().expect("job page two");
    assert_eq!(job_page_two.len(), 1);
    assert_eq!(
        job_page_two[0]["id"].as_str(),
        Some(script_review_id_text.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/quality/reviews?jobId={quality_job_id}&targetType=asset&isBadCase=true"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, combined_filters) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "combined_filters={combined_filters}"
    );
    let combined_filters = combined_filters.as_array().expect("combined filter rows");
    assert_eq!(combined_filters.len(), 1);
    assert_eq!(
        combined_filters[0]["id"].as_str(),
        Some(asset_review_id_text.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/quality/reviews?targetId={script_target_id}&limit=1&offset=0"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, target_id_only) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "target_id_only={target_id_only}");
    let target_id_only = target_id_only.as_array().expect("target id only rows");
    assert_eq!(target_id_only.len(), 1);
    assert_eq!(
        target_id_only[0]["id"].as_str(),
        Some(script_review_id_text.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/quality/reviews/{script_review_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, review_by_id) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "review_by_id={review_by_id}");
    assert_eq!(
        review_by_id["targetId"].as_str(),
        Some(script_target_id.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/quality/stats")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, stats) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "stats={stats}");
    let stats = stats.as_array().expect("stats list");
    let script_stats = stats
        .iter()
        .find(|row| row["targetType"].as_str() == Some("script"))
        .expect("script stats row");
    assert!(
        script_stats["totalReviews"].as_i64().unwrap_or_default() >= 1,
        "script stats={script_stats}"
    );
    assert!(
        script_stats["passedCount"].as_i64().unwrap_or_default() >= 1,
        "script stats={script_stats}"
    );
    assert!(
        script_stats["deliveryPriorityTotalReviews"]
            .as_i64()
            .unwrap_or_default()
            >= 1,
        "script stats={script_stats}"
    );
    assert!(
        script_stats["deliveryPriorityPassedCount"]
            .as_i64()
            .unwrap_or_default()
            >= 1,
        "script stats={script_stats}"
    );
    let asset_stats = stats
        .iter()
        .find(|row| row["targetType"].as_str() == Some("asset"))
        .expect("asset stats row");
    assert!(
        asset_stats["badCaseCount"].as_i64().unwrap_or_default() >= 1,
        "asset stats={asset_stats}"
    );
    assert!(
        asset_stats["failedCount"].as_i64().unwrap_or_default() >= 1,
        "asset stats={asset_stats}"
    );
    assert!(
        asset_stats["nonDeliveryPriorityTotalReviews"]
            .as_i64()
            .unwrap_or_default()
            >= 1,
        "asset stats={asset_stats}"
    );

    let linked_usage = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)::bigint
        FROM public.app_llm_usage_log
        WHERE quality_review_id = $1
        "#,
    )
    .bind(script_review_id)
    .fetch_one(&pool)
    .await
    .expect("linked llm usage count");
    assert_eq!(linked_usage, 1);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/quality/token-efficiency")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, token_efficiency) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "token_efficiency={token_efficiency}"
    );
    let token_efficiency = token_efficiency.as_array().expect("token efficiency list");
    let script_efficiency = token_efficiency
        .iter()
        .find(|row| row["targetType"].as_str() == Some("script"))
        .expect("script token efficiency row");
    assert_eq!(script_efficiency["linkedLlmReviewCount"], 1);
    assert_eq!(script_efficiency["avgLinkedTotalTokens"], 200.0);
    assert_eq!(script_efficiency["avgLinkedTokensPerScorePoint"], 25.0);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/quality/stage-pass-rate")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, stage_rows) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "stage_rows={stage_rows}");
    let stage_rows = stage_rows.as_array().expect("stage pass rate list");
    assert!(
        stage_rows.iter().any(|row| {
            row["targetType"].as_str() == Some("script")
                && row["passedCount"].as_i64().unwrap_or_default() >= 1
                && row["deliveryPriorityTotalReviews"]
                    .as_i64()
                    .unwrap_or_default()
                    >= 1
        }),
        "stage rows should include script aggregate: {stage_rows:?}"
    );
    assert!(
        stage_rows.iter().any(|row| {
            row["targetType"].as_str() == Some("asset")
                && row["badCaseCount"].as_i64().unwrap_or_default() >= 1
                && row["nonDeliveryPriorityTotalReviews"]
                    .as_i64()
                    .unwrap_or_default()
                    >= 1
        }),
        "stage rows should include asset aggregate: {stage_rows:?}"
    );

    cleanup_llm_usage_rows_for_jobs(&pool, &created_job_ids).await;
    cleanup_quality_reviews(&pool, &created_review_ids).await;
    cleanup_jobs(&pool, &created_job_ids).await;
}
