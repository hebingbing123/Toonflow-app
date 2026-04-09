use super::*;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn settings_vendor_model_test_enqueue() {
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
    let app = build_router(contract_state(pool, secret));

    let body = r#"{"modelName":"pg_vendor_mt","type":"text","id":"probe-id"}"#;
    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/model-test")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "model-test body={job}");
    assert_eq!(
        job["kind"].as_str(),
        Some(JOB_KIND_SETTINGS_VENDOR_MODEL_TEST)
    );
    assert_eq!(job["status"].as_str(), Some("queued"));
}

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
    let script_review_id_text;
    let asset_review_id_text;

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
                    r#"{{"targetType":"script","targetId":"{script_target_id}","jobId":"{quality_job_id}","source":"auto","overallScore":8,"passed":true,"comments":"pg quality script"}}"#
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
    let script_review_id =
        Uuid::parse_str(created_script["id"].as_str().expect("script review id")).unwrap();
    script_review_id_text = script_review_id.to_string();
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
    asset_review_id_text = asset_review_id.to_string();
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
        }),
        "stage rows should include script aggregate: {stage_rows:?}"
    );
    assert!(
        stage_rows.iter().any(|row| {
            row["targetType"].as_str() == Some("asset")
                && row["badCaseCount"].as_i64().unwrap_or_default() >= 1
        }),
        "stage rows should include asset aggregate: {stage_rows:?}"
    );

    cleanup_quality_reviews(&pool, &created_review_ids).await;
    cleanup_jobs(&pool, &created_job_ids).await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
async fn settings_memory_config_and_clear_agent_memories_roundtrip() {
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
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "created={created}");
    let project_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/memory-config")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, default_cfg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "default_cfg={default_cfg}");
    assert_eq!(default_cfg["messagesPerSummary"].as_i64(), Some(10));
    assert_eq!(default_cfg["modelDtype"].as_str(), Some("fp16"));

    let custom_cfg = r#"{"messagesPerSummary":12,"shortTermLimit":7,"summaryMaxLength":640,"summaryLimit":11,"ragLimit":4,"deepRetrieveSummaryLimit":6,"modelOnnxFile":["custom","onnx","model.onnx"],"modelDtype":"int8"}"#;
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/memory-config")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(custom_cfg))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, saved) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "saved={saved}");
    assert_eq!(saved["message"].as_str(), Some("保存设置成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/memory-config")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, fetched_cfg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "fetched_cfg={fetched_cfg}");
    assert_eq!(fetched_cfg["messagesPerSummary"].as_i64(), Some(12));
    assert_eq!(fetched_cfg["shortTermLimit"].as_i64(), Some(7));
    assert_eq!(fetched_cfg["modelDtype"].as_str(), Some("int8"));

    let stored_cfg: Option<Json<MemoryConfig>> =
        sqlx::query_scalar("SELECT memory_config FROM public.app_user_profile WHERE user_id = $1")
            .bind(sub)
            .fetch_optional(&pool)
            .await
            .expect("select memory_config");
    let stored_cfg = stored_cfg.expect("stored memory_config").0;
    assert_eq!(stored_cfg.messages_per_summary, 12);
    assert_eq!(stored_cfg.model_dtype, "int8");

    for body in [
        format!(
            r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7,"role":"user","content":"episode scoped memory"}}"#
        ),
        format!(
            r#"{{"projectId":{project_id},"agentType":"scriptAgent","role":"assistant","content":"project scoped memory"}}"#
        ),
    ] {
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/agents/memory/append")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, appended) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "appended={appended}");
        assert!(appended["id"].as_str().is_some());
    }

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/agents/memory/query")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, episode_memory) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "episode_memory={episode_memory}");
    assert_eq!(episode_memory.as_array().map(|a| a.len()), Some(1));
    assert_eq!(
        episode_memory[0]["content"][0]["data"].as_str(),
        Some("episode scoped memory")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/memory-config/clear-agent-memories")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cleared) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "cleared={cleared}");
    assert_eq!(cleared["ok"].as_bool(), Some(true));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/agents/memory/query")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, episode_memory_after_clear) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "episode_memory_after_clear={episode_memory_after_clear}"
    );
    assert_eq!(
        episode_memory_after_clear.as_array().map(|a| a.len()),
        Some(0)
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/agents/memory/query")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, project_memory) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "project_memory={project_memory}");
    assert_eq!(project_memory.as_array().map(|a| a.len()), Some(1));
    assert_eq!(
        project_memory[0]["content"][0]["data"].as_str(),
        Some("project scoped memory")
    );

    let _ = sqlx::query(
        "DELETE FROM public.app_agent_memory WHERE owner_user_id = $1 AND legacy_project_id = $2",
    )
    .bind(sub)
    .bind(project_id)
    .execute(&pool)
    .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
async fn vendor_credential_store_get_delete_roundtrip() {
    let _guard = vendor_credential_test_lock().await;
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

    // Set encryption key for test
    std::env::set_var(
        "TOONFLOW_VENDOR_CREDENTIAL_KEY",
        "test-encryption-key-for-contract-tests",
    );

    let vendor_id = "openai";

    // Store credential
    let store_body = format!(
        r#"{{"vendorId":"{}","apiKey":"sk-test1234567890","apiSecret":"secret123","apiToken":"token123"}}"#,
        vendor_id
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/credential")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(store_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, stored) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "store credential={stored}");
    assert_eq!(stored["vendorId"].as_str(), Some(vendor_id));
    assert_eq!(stored["keyHint"].as_str(), Some("...7890"));
    assert_eq!(stored["hasSecret"].as_bool(), Some(true));
    assert_eq!(stored["hasToken"].as_bool(), Some(true));
    assert_eq!(
        stored["message"].as_str(),
        Some("Credential stored securely")
    );

    // Get credential metadata
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/settings/vendors/credential/{}", vendor_id))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, got) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get credential={got}");
    assert_eq!(got["vendorId"].as_str(), Some(vendor_id));
    assert_eq!(got["keyHint"].as_str(), Some("...7890"));
    assert_eq!(got["hasSecret"].as_bool(), Some(true));
    assert_eq!(got["hasToken"].as_bool(), Some(true));

    // Delete credential
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/settings/vendors/credential/{}", vendor_id))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, deleted) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "delete credential={deleted}");
    assert_eq!(deleted["vendorId"].as_str(), Some(vendor_id));
    assert_eq!(deleted["message"].as_str(), Some("Credential deleted"));

    // Verify deletion - should get 404
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/settings/vendors/credential/{}", vendor_id))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "credential should be deleted"
    );

    // Cleanup
    let _ = sqlx::query("DELETE FROM public.app_vendor_credential WHERE owner_user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;

    // Clean up env var
    std::env::remove_var("TOONFLOW_VENDOR_CREDENTIAL_KEY");
}
