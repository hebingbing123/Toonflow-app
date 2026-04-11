use super::*;

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
    let legacy_project_id = created_project["legacy_id"]
        .as_i64()
        .expect("legacy project id") as i32;

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
                    r#"{{"kind":"flutter.probe","payload":{{"project_legacy_id":"{legacy_project_id}","scope":"task-center","marker":"idem"}}}}"#
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
                    r#"{{"kind":"flutter.probe","payload":{{"project_legacy_id":"{legacy_project_id}","scope":"task-center","marker":"idem-retry"}}}}"#
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
                    r#"{{"kind":"{JOB_KIND_ASSET_GENERATE_IMAGE}","payload":{{"project_legacy_id":"{legacy_project_id}","scope":"task-center","marker":"failed"}}}}"#
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
            row["legacy_id"].as_i64() == Some(i64::from(legacy_project_id))
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
                    "/api/v1/jobs/page?page=1&limit=10&project_id={legacy_project_id}&task_class=flutter.probe&state=queued"
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
                    "/api/v1/jobs/page?page=1&limit=10&project_id={legacy_project_id}&state=failed"
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
    assert_eq!(task_detail["legacy_task_id"], created_job["legacy_task_id"]);
    let legacy_project_id_text = legacy_project_id.to_string();
    assert_eq!(
        task_detail["payload"]["project_legacy_id"].as_str(),
        Some(legacy_project_id_text.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!(
                    "/api/v1/jobs/task-detail/{}",
                    created_job["legacy_task_id"]
                        .as_i64()
                        .expect("legacy task id")
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
        task_detail_by_int["legacy_task_id"],
        created_job["legacy_task_id"]
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!(
                    "/api/v1/jobs/task-detail/{}",
                    created_job["legacy_task_id"]
                        .as_i64()
                        .expect("legacy task id")
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
    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(legacy_project_id)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn novel_events_crud_roundtrip() {
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

    // Create project
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
    let project_uuid = created["id"].as_str().expect("project id");

    // Add novels first to have chapter_ids to associate
    let add_novel_body = format!(
        r#"{{"projectId":{},"data":[{{"index":1,"reel":"卷一","chapter":"第一章","chapterData":"第一章内容"}},{{"index":2,"reel":"卷一","chapter":"第二章","chapterData":"第二章内容"}}]}}"#,
        project_id
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/add-novel")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(add_novel_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "add novels");

    // Create event
    let create_body = r#"{"name":"测试事件","detail":"事件详情","chapterIds":[1,2]}"#.to_string();
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/novel-events",))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(create_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, event) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "create event={event}");
    assert_eq!(event["name"].as_str(), Some("测试事件"));
    let event_id = event["id"].as_i64().expect("event id") as i32;

    // List events
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/projects/{project_uuid}/novel-events",))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list={list}");
    assert_eq!(list["total"].as_i64(), Some(1));
    let items = list["items"].as_array().expect("items");
    assert_eq!(items.len(), 1);
    assert_eq!(items[0]["name"].as_str(), Some("测试事件"));
    let chapters = items[0]["chapterIndexes"].as_array().expect("chapters");
    assert_eq!(chapters.len(), 2);

    // Update event
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novel-events/{event_id}",
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"name":"更新后事件"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "update event");

    // Verify update
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/projects/{project_uuid}/novel-events",))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list2) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list2={list2}");
    assert_eq!(list2["items"][0]["name"].as_str(), Some("更新后事件"));

    // Delete event
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novel-events/{event_id}",
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "delete event");

    // Verify deletion
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/projects/{project_uuid}/novel-events",))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, empty_list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "empty_list={empty_list}");
    assert_eq!(empty_list["total"].as_i64(), Some(0));

    // Cleanup
    let _ = sqlx::query("DELETE FROM public.app_novel WHERE project_id IN (SELECT id FROM public.app_project WHERE legacy_id = $1)")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn novel_events_generate_events_async_fallback_roundtrip() {
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
    let project_legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

    let add_novel_body = format!(
        r#"{{"projectId":{},"data":[{{"index":1,"reel":"卷一","chapter":"第一章","chapterData":"第一章内容"}},{{"index":2,"reel":"卷一","chapter":"第二章","chapterData":"第二章内容"}}]}}"#,
        project_legacy_id
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/add-novel")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(add_novel_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, add_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "add_msg={add_msg}");

    let novel_rows: Vec<(i32,)> = sqlx::query_as(
        r#"
        SELECT n.legacy_id
        FROM public.app_novel n
        INNER JOIN public.app_project p ON p.id = n.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
        ORDER BY n.chapter_index ASC, n.legacy_id ASC
        "#,
    )
    .bind(project_legacy_id)
    .bind(sub)
    .fetch_all(&pool)
    .await
    .expect("list novel legacy ids");
    let novel_legacy_ids: Vec<i32> = novel_rows.into_iter().map(|(id,)| id).collect();
    assert_eq!(novel_legacy_ids.len(), 2, "expected two novels");

    sqlx::query(
        r#"
        UPDATE public.app_novel n
        SET event = '历史事件', event_state = 1, error_reason = NULL
        FROM public.app_project p
        WHERE n.project_id = p.id
          AND p.legacy_id = $1
          AND p.owner_user_id = $2
          AND n.legacy_id = ANY($3)
        "#,
    )
    .bind(project_legacy_id)
    .bind(sub)
    .bind(&novel_legacy_ids)
    .execute(&pool)
    .await
    .expect("seed existing events");

    let payload = serde_json::json!({
        "projectId": project_legacy_id,
        "novelIds": novel_legacy_ids,
        "concurrentCount": 2
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/events/generate-events")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(payload.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "generate-events body={body}");
    assert_eq!(body["message"].as_str(), Some("生成事件成功"));

    let reset_rows: Vec<(Option<String>, i32, Option<String>)> = sqlx::query_as(
        r#"
        SELECT n.event, n.event_state, n.error_reason
        FROM public.app_novel n
        INNER JOIN public.app_project p ON p.id = n.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND n.legacy_id = ANY($3)
        ORDER BY n.chapter_index ASC, n.legacy_id ASC
        "#,
    )
    .bind(project_legacy_id)
    .bind(sub)
    .bind(&novel_legacy_ids)
    .fetch_all(&pool)
    .await
    .expect("rows immediately after enqueue");
    assert!(
        reset_rows
            .iter()
            .all(|(event, state, reason)| event.is_none() && *state == 0 && reason.is_none()),
        "expected reset to pending before async extraction: {reset_rows:?}"
    );

    let mut final_rows: Vec<(i32, Option<String>, i32, Option<String>)> = Vec::new();
    for _ in 0..40 {
        final_rows = sqlx::query_as(
            r#"
            SELECT n.legacy_id, n.event, n.event_state, n.error_reason
            FROM public.app_novel n
            INNER JOIN public.app_project p ON p.id = n.project_id
            WHERE p.legacy_id = $1
              AND p.owner_user_id = $2
              AND n.legacy_id = ANY($3)
            ORDER BY n.chapter_index ASC, n.legacy_id ASC
            "#,
        )
        .bind(project_legacy_id)
        .bind(sub)
        .bind(&novel_legacy_ids)
        .fetch_all(&pool)
        .await
        .expect("poll extraction rows");
        if final_rows
            .iter()
            .all(|(_, _, state, _)| *state == -1 || *state == 1)
        {
            break;
        }
        tokio::time::sleep(std::time::Duration::from_millis(25)).await;
    }

    assert!(
        final_rows.iter().all(|(_, event, state, reason)| {
            event.is_none() && *state == -1 && reason.as_deref() == Some("llm_not_configured")
        }),
        "expected llm_not_configured fallback rows: {final_rows:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/get-novel-event-state")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    serde_json::json!({ "ids": novel_legacy_ids }).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, state_rows) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "state_rows={state_rows}");
    let data = state_rows["data"].as_array().expect("state data array");
    assert_eq!(
        data.len(),
        2,
        "both novels should be visible in non-zero legacy event state list: {state_rows}"
    );
    assert!(
        data.iter()
            .all(|row| row["event_state"].as_i64() == Some(-1)),
        "legacy event_state should expose fallback failures: {state_rows}"
    );

    let _ = sqlx::query("DELETE FROM public.app_novel WHERE project_id IN (SELECT id FROM public.app_project WHERE legacy_id = $1)")
        .bind(project_legacy_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(project_legacy_id)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
async fn script_agent_plan_roundtrip() {
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
                .method(Method::POST)
                .uri("/api/v1/script-agent/get-plan-data")
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
    let (status, initial_plan) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "initial_plan={initial_plan}");
    assert_eq!(initial_plan["code"].as_i64(), Some(200));
    assert_eq!(initial_plan["data"]["storySkeleton"].as_str(), Some(""));
    assert_eq!(
        initial_plan["data"]["adaptationStrategy"].as_str(),
        Some("")
    );

    let set_body = serde_json::json!({
        "projectId": project_id,
        "agentType": "scriptAgent",
        "data": {
            "storySkeleton": "三幕短剧",
            "adaptationStrategy": "先冲突后反转",
            "script": [
                { "name": "第1集", "content": "第一集内容" },
                { "name": "第2集", "content": "第二集内容" }
            ]
        }
    })
    .to_string();
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/set-plan-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(set_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, set_ok) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "set_ok={set_ok}");
    assert_eq!(set_ok["code"].as_i64(), Some(200));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/get-plan-data")
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
    let (status, fetched_plan) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "fetched_plan={fetched_plan}");
    assert_eq!(
        fetched_plan["data"]["data"]["storySkeleton"].as_str(),
        Some("三幕短剧")
    );
    assert_eq!(
        fetched_plan["data"]["data"]["adaptationStrategy"].as_str(),
        Some("先冲突后反转")
    );
    let plan_id = fetched_plan["data"]["id"].as_i64().expect("plan id");
    let scripts = fetched_plan["data"]["data"]["script"]
        .as_array()
        .expect("scripts array");
    assert_eq!(scripts.len(), 2);
    assert_eq!(scripts[0]["name"].as_str(), Some("第1集"));
    assert_eq!(scripts[0]["content"].as_str(), Some("第一集内容"));
    let script_row_id = scripts[0]["id"].as_i64().expect("script row id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/set-plan-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    serde_json::json!({
                        "projectId": project_id,
                        "agentType": "scriptAgent",
                        "data": {
                            "storySkeleton": "四幕短剧",
                            "adaptationStrategy": "强化人物弧光",
                            "script": [
                                { "name": "第1集", "content": "第一集修订版" }
                            ]
                        }
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, set_again_ok) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "set_again_ok={set_again_ok}");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/get-plan-data")
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
    let (status, fetched_after_update) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "fetched_after_update={fetched_after_update}"
    );
    assert_eq!(
        fetched_after_update["data"]["data"]["storySkeleton"].as_str(),
        Some("四幕短剧")
    );
    let scripts_after_update = fetched_after_update["data"]["data"]["script"]
        .as_array()
        .expect("scripts_after_update");
    assert_eq!(
        scripts_after_update.len(),
        2,
        "existing unnamed rows preserved"
    );
    assert_eq!(
        scripts_after_update[0]["content"].as_str(),
        Some("第一集修订版")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/update-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    serde_json::json!({
                        "id": plan_id,
                        "data": {
                            "storySkeleton": "终稿大纲",
                            "adaptationStrategy": "保留反转",
                            "script": [
                                { "id": script_row_id, "content": "终稿正文" }
                            ]
                        }
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, updated_data) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "updated_data={updated_data}");
    assert_eq!(updated_data["data"].as_str(), Some("更新成功"));

    let stored_plan: Option<Value> = sqlx::query_scalar(
        r#"
        SELECT plan_data
        FROM public.app_script_agent_plan
        WHERE owner_user_id = $1
          AND project_id IN (
            SELECT id FROM public.app_project WHERE legacy_id = $2
          )
          AND agent_key = 'scriptAgent'
        "#,
    )
    .bind(sub)
    .bind(project_id)
    .fetch_optional(&pool)
    .await
    .expect("select plan_data");
    let stored_plan = stored_plan.expect("stored plan_data");
    assert_eq!(stored_plan["storySkeleton"].as_str(), Some("终稿大纲"));
    assert_eq!(stored_plan["adaptationStrategy"].as_str(), Some("保留反转"));
    assert_eq!(
        stored_plan["script"][0]["id"].as_i64(),
        Some(i64::from(script_row_id))
    );
    assert_eq!(
        stored_plan["script"][0]["content"].as_str(),
        Some("终稿正文")
    );

    let _ = sqlx::query(
        "DELETE FROM public.app_script WHERE project_id IN (SELECT id FROM public.app_project WHERE legacy_id = $1)",
    )
    .bind(project_id)
    .execute(&pool)
    .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}
