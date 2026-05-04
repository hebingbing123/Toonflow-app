use super::super::*;
use tower::ServiceExt;

async fn create_project_and_script(app: &axum::Router, token: &str) -> (i32, String, i32) {
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
    let (status, created_project) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CREATED,
        "created_project={created_project}"
    );
    let project_id = created_project["numeric_id"]
        .as_i64()
        .expect("project numeric_id") as i32;
    let project_uuid = created_project["id"]
        .as_str()
        .expect("project uuid")
        .to_string();

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/scripts"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"name":"quality review scope script"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created_script) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CREATED,
        "created_script={created_script}"
    );
    let script_id = created_script["numeric_id"]
        .as_i64()
        .expect("script numeric_id") as i32;

    (project_id, project_uuid, script_id)
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
    let (owned_project_id, _owned_project_uuid, owned_script_id) =
        create_project_and_script(&app, &token).await;
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
                .method(Method::POST)
                .uri("/api/v1/quality/reviews")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{owned_project_id},"scriptId":99999999,"targetType":"script","targetId":"bad-scope","overallScore":8,"passed":true}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, invalid_script_scope) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "invalid_script_scope={invalid_script_scope}"
    );

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
                    r#"{{"projectId":{owned_project_id},"scriptId":{owned_script_id},"targetType":"script","targetId":"owned-scope","overallScore":8,"passed":true}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, owned_scope_review) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "owned_scope_review={owned_scope_review}"
    );
    let owned_scope_review_id = Uuid::parse_str(
        owned_scope_review["id"]
            .as_str()
            .expect("owned scope review id"),
    )
    .unwrap();
    created_review_ids.push(owned_scope_review_id);

    let output_target_id = format!("pg_quality_output_{}", Uuid::new_v4());
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
                    r#"{{"projectId":{owned_project_id},"scriptId":{owned_script_id},"targetType":"output","targetId":"{output_target_id}","source":"auto","modelName":"runway-gen-2","modelParams":{{"diagnostics":{{"promptChars":321}}}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, placeholder_auto_review) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "placeholder_auto_review={placeholder_auto_review}"
    );
    let placeholder_auto_review_id = Uuid::parse_str(
        placeholder_auto_review["id"]
            .as_str()
            .expect("placeholder auto review id"),
    )
    .unwrap();
    created_review_ids.push(placeholder_auto_review_id);

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
                    r#"{{"projectId":{owned_project_id},"scriptId":{owned_script_id},"targetType":"output","targetId":"{output_target_id}-scored","source":"auto","overallScore":9,"passed":true,"skillFilePath":"skills/video_prompt/reviewer.md","skillVersionHash":"hash-scored-output","comments":"scored output review"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, scored_output_review) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "scored_output_review={scored_output_review}"
    );
    let scored_output_review_id = Uuid::parse_str(
        scored_output_review["id"]
            .as_str()
            .expect("scored output review id"),
    )
    .unwrap();
    created_review_ids.push(scored_output_review_id);

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
                    r#"{{"projectId":{owned_project_id},"scriptId":{owned_script_id},"targetType":"storyboard","targetId":"99999999","overallScore":8,"passed":true}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, invalid_storyboard_scope) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "invalid_storyboard_scope={invalid_storyboard_scope}"
    );

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
        stats.iter().all(|row| row["targetType"].as_str() != Some("output")),
        "placeholder auto output review should not skew scored stats: {stats:?}"
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
    assert!(
        stage_rows
            .iter()
            .all(|row| row["targetType"].as_str() != Some("output")),
        "placeholder auto output review should not skew stage pass rate: {stage_rows:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/quality/skill-version-comparison")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, skill_version_rows) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "skill_version_rows={skill_version_rows}"
    );
    let skill_version_rows = skill_version_rows
        .as_array()
        .expect("skill version comparison rows");
    let scored_output_row = skill_version_rows
        .iter()
        .find(|row| row["skillVersionHash"].as_str() == Some("hash-scored-output"))
        .expect("scored output skill-version row");
    assert_eq!(
        scored_output_row["totalCount"].as_i64(),
        Some(1),
        "scored skill-version row should ignore placeholder auto reviews: {skill_version_rows:?}"
    );
    assert_eq!(
        scored_output_row["passRatePercent"].as_f64(),
        Some(100.0),
        "placeholder auto reviews should not dilute skill-version pass rate: {skill_version_rows:?}"
    );

    cleanup_quality_reviews(&pool, &created_review_ids).await;
    cleanup_jobs(&pool, &created_job_ids).await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
        .bind(owned_project_id)
        .execute(&pool)
        .await;
}
