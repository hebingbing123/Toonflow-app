use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_polling_image_and_prompt_filters_roundtrip() {
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
    let project_numeric_id = created_project["numeric_id"]
        .as_i64()
        .expect("project numeric id") as i32;
    let project_uuid = created_project["id"].as_str().expect("project uuid");

    let ready_asset_name = format!("pg_polling_ready_{}", Uuid::new_v4());
    let running_asset_name = format!("pg_polling_running_{}", Uuid::new_v4());

    let (status, ready_asset) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{ready_asset_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "ready_asset={ready_asset}");
    let ready_asset_numeric_id = ready_asset["numeric_id"]
        .as_i64()
        .expect("ready asset numeric id") as i32;

    let (status, running_asset) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{running_asset_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "running_asset={running_asset}");
    let running_asset_numeric_id = running_asset["numeric_id"]
        .as_i64()
        .expect("running asset numeric id") as i32;

    let ready_asset_uuid: Uuid = sqlx::query_scalar(
        r#"SELECT id
           FROM app_asset
           WHERE project_id = (SELECT id FROM app_project WHERE numeric_id = $1 AND owner_user_id = $2)
             AND numeric_id = $3"#,
    )
    .bind(project_numeric_id)
    .bind(sub)
    .bind(ready_asset_numeric_id)
    .fetch_one(&pool)
    .await
    .expect("ready asset uuid");
    let running_asset_uuid: Uuid = sqlx::query_scalar(
        r#"SELECT id
           FROM app_asset
           WHERE project_id = (SELECT id FROM app_project WHERE numeric_id = $1 AND owner_user_id = $2)
             AND numeric_id = $3"#,
    )
    .bind(project_numeric_id)
    .bind(sub)
    .bind(running_asset_numeric_id)
    .fetch_one(&pool)
    .await
    .expect("running asset uuid");

    let ready_image_numeric_id = 9_902_001;
    let running_image_numeric_id = 9_902_002;

    sqlx::query(
        r#"
        UPDATE app_asset
        SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{imageId}', to_jsonb($1::integer), true)
        WHERE id = $2
        "#,
    )
    .bind(ready_image_numeric_id)
    .bind(ready_asset_uuid)
    .execute(&pool)
    .await
    .expect("set ready imageId");

    sqlx::query(
        r#"
        UPDATE app_asset
        SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{imageId}', to_jsonb($1::integer), true)
        WHERE id = $2
        "#,
    )
    .bind(running_image_numeric_id)
    .bind(running_asset_uuid)
    .execute(&pool)
    .await
    .expect("set running imageId");

    sqlx::query(
        r#"
        INSERT INTO app_asset_image (asset_id, sort_index, file_path, state, numeric_image_id)
        VALUES
          ($1, 0, '/tmp/pg_polling_ready.png', '已完成', $2),
          ($3, 0, '/tmp/pg_polling_running.png', '生成中', $4)
        "#,
    )
    .bind(ready_asset_uuid)
    .bind(ready_image_numeric_id)
    .bind(running_asset_uuid)
    .bind(running_image_numeric_id)
    .execute(&pool)
    .await
    .expect("insert selected images");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/polling-image-assets"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"ids":[{ready_asset_numeric_id},{running_asset_numeric_id}]}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, polling_image) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "polling_image={polling_image}");
    let rows = polling_image.as_array().expect("polling image rows");
    assert_eq!(rows.len(), 1);
    assert_eq!(
        rows[0]["id"].as_i64(),
        Some(i64::from(ready_asset_numeric_id))
    );
    assert_eq!(
        rows[0]["filePath"].as_str(),
        Some("/tmp/pg_polling_ready.png")
    );
    assert_eq!(rows[0]["state"].as_str(), Some("已完成"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .header(
                    "Idempotency-Key",
                    format!("polling-ready-{}", Uuid::new_v4()),
                )
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"kind":"{JOB_KIND_ASSET_POLISH_PROMPT}","payload":{{"project_numeric_id":{project_numeric_id},"asset_numeric_id":{ready_asset_numeric_id},"asset_type":"role","name":"pg_polish_ready","describe":"d"}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, ready_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "ready_job={ready_job}");
    let ready_job_id = ready_job["id"].as_str().expect("ready job id");
    sqlx::query(r#"UPDATE app_generation_job SET status = 'failed' WHERE id = $1::uuid"#)
        .bind(ready_job_id)
        .execute(&pool)
        .await
        .expect("mark ready job failed");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .header(
                    "Idempotency-Key",
                    format!("polling-running-{}", Uuid::new_v4()),
                )
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"kind":"{JOB_KIND_ASSET_POLISH_PROMPT}","payload":{{"project_numeric_id":{project_numeric_id},"asset_numeric_id":{running_asset_numeric_id},"asset_type":"role","name":"pg_polish_running","describe":"d"}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, running_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "running_job={running_job}");
    assert_eq!(running_job["status"].as_str(), Some("queued"));

    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/polling-prompt-assets"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"ids":[{ready_asset_numeric_id},{running_asset_numeric_id}]}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, polling_prompt) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "polling_prompt={polling_prompt}");
    let rows = polling_prompt.as_array().expect("polling prompt rows");
    assert_eq!(rows.len(), 1);
    assert_eq!(
        rows[0]["id"].as_i64(),
        Some(i64::from(ready_asset_numeric_id))
    );
    assert_eq!(rows[0]["promptState"].as_str(), Some("失败"));
    assert_eq!(rows[0]["name"].as_str(), Some(ready_asset_name.as_str()));
    assert_eq!(rows[0]["type"].as_str(), Some("role"));
}
