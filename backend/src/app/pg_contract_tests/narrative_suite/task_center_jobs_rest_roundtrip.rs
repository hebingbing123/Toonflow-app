use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn task_center_jobs_rest_roundtrip() {
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

    let project_name = format!("pg_task_center_{}", Uuid::new_v4());
    let idem_key = format!("pg-task-idem-{}", Uuid::new_v4());
    let mut created_job_ids = Vec::new();

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"name":"{project_name}"}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created_project) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "project={created_project}");
    let numeric_project_id = created_project["numeric_id"]
        .as_i64()
        .expect("numeric project id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .header("Idempotency-Key", idem_key.as_str())
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"kind":"flutter.probe","payload":{{"project_numeric_id":"{numeric_project_id}","scope":"task-center","marker":"idem"}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "created_job={created_job}");
    let created_job_id =
        Uuid::parse_str(created_job["id"].as_str().expect("created job id")).unwrap();
    created_job_ids.push(created_job_id);
    assert_eq!(
        created_job["idempotency_key"].as_str(),
        Some(idem_key.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .header("Idempotency-Key", idem_key.as_str())
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"kind":"flutter.probe","payload":{{"project_numeric_id":"{numeric_project_id}","scope":"task-center","marker":"idem-retry"}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, idem_retry) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "idem_retry={idem_retry}");
    assert_eq!(idem_retry["id"], created_job["id"]);
    assert_eq!(idem_retry["payload"]["marker"], "idem");

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
                    r#"{{"kind":"{JOB_KIND_ASSET_GENERATE_IMAGE}","payload":{{"project_numeric_id":"{numeric_project_id}","scope":"task-center","marker":"failed"}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, failed_seed_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "failed_seed_job={failed_seed_job}");
    let failed_seed_job_id =
        Uuid::parse_str(failed_seed_job["id"].as_str().expect("failed seed job id")).unwrap();
    created_job_ids.push(failed_seed_job_id);

    sqlx::query(
        "UPDATE public.app_generation_job SET status = 'failed', error_message = 'pg task center failure' WHERE id = $1",
    )
    .bind(failed_seed_job_id)
    .execute(&pool)
    .await
    .expect("mark failed seed job");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/projects?limit=100&offset=0")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, task_projects) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "task_projects={task_projects}");
    let task_projects = task_projects.as_array().expect("task project rows");
    assert!(
        task_projects.iter().any(|row| {
            row["numeric_id"].as_i64() == Some(i64::from(numeric_project_id))
                && row["name"].as_str() == Some(project_name.as_str())
        }),
        "task center project list should include created project: {task_projects:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/jobs/kinds")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, task_categories) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "task_categories={task_categories}");
    let task_categories = task_categories.as_array().expect("task category rows");
    assert!(
        task_categories
            .iter()
            .any(|row| row.as_str() == Some("flutter.probe")),
        "task categories should include flutter.probe: {task_categories:?}"
    );
    assert!(
        task_categories
            .iter()
            .any(|row| row.as_str() == Some(JOB_KIND_ASSET_GENERATE_IMAGE)),
        "task categories should include asset generate: {task_categories:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!(
                    "/api/v1/jobs/page?page=1&limit=10&project_id={numeric_project_id}&task_class=flutter.probe&state=queued"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, filtered_jobs) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "filtered_jobs={filtered_jobs}");
    assert_eq!(filtered_jobs["total"].as_i64(), Some(1));
    let filtered_jobs = filtered_jobs["data"]
        .as_array()
        .expect("filtered task rows");
    assert_eq!(filtered_jobs.len(), 1);
    assert_eq!(filtered_jobs[0]["id"], created_job["id"]);
    assert_eq!(filtered_jobs[0]["status"], "queued");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/jobs/page?page=1&limit=10&task_class=flutter.probe&state=queued")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, zero_project_filter_jobs) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "zero_project_filter_jobs={zero_project_filter_jobs}"
    );
    assert_eq!(zero_project_filter_jobs["total"].as_i64(), Some(1));
    let zero_project_filter_jobs = zero_project_filter_jobs["data"]
        .as_array()
        .expect("zero project filter task rows");
    assert_eq!(zero_project_filter_jobs.len(), 1);
    assert_eq!(zero_project_filter_jobs[0]["id"], created_job["id"]);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!(
                    "/api/v1/jobs/page?page=1&limit=10&project_id={numeric_project_id}&state=failed"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, failed_jobs) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "failed_jobs={failed_jobs}");
    assert_eq!(failed_jobs["total"].as_i64(), Some(1));
    let failed_jobs = failed_jobs["data"].as_array().expect("failed task rows");
    assert_eq!(failed_jobs.len(), 1);
    assert_eq!(failed_jobs[0]["id"], failed_seed_job["id"]);
    assert_eq!(failed_jobs[0]["status"], "failed");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/jobs/task-detail/{created_job_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, task_detail) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "task_detail={task_detail}");
    assert_eq!(task_detail["id"], created_job["id"]);
    assert_eq!(
        task_detail["numeric_task_id"],
        created_job["numeric_task_id"]
    );
    let numeric_project_id_text = numeric_project_id.to_string();
    assert_eq!(
        task_detail["payload"]["project_numeric_id"].as_str(),
        Some(numeric_project_id_text.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!(
                    "/api/v1/jobs/task-detail/{}",
                    created_job["numeric_task_id"]
                        .as_i64()
                        .expect("numeric task id")
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, task_detail_by_int) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "task_detail_by_int={task_detail_by_int}"
    );
    assert_eq!(task_detail_by_int["id"], created_job["id"]);
    assert_eq!(
        task_detail_by_int["numeric_task_id"],
        created_job["numeric_task_id"]
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!(
                    "/api/v1/jobs/task-detail/{}",
                    created_job["numeric_task_id"]
                        .as_i64()
                        .expect("numeric task id")
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, task_detail_by_numeric_string) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "task_detail_by_numeric_string={task_detail_by_numeric_string}"
    );
    assert_eq!(task_detail_by_numeric_string["id"], created_job["id"]);

    cleanup_jobs(&pool, &created_job_ids).await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
        .bind(numeric_project_id)
        .execute(&pool)
        .await;
}
