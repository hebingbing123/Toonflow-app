use super::super::*;
use tower::ServiceExt;

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
