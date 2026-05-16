use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_generate_cancel_generate_roundtrip() {
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
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "body={created}");
    let numeric_id = created["numeric_id"].as_i64().expect("numeric_id") as i32;

    let project_id: Uuid = sqlx::query_scalar(
        r#"SELECT id FROM public.app_project WHERE numeric_id = $1 AND owner_user_id = $2"#,
    )
    .bind(numeric_id)
    .bind(sub)
    .fetch_one(&pool)
    .await
    .expect("project uuid by numeric id");

    let asset_id = Uuid::new_v4();
    let asset_numeric_id = 7_000_001_i32;
    let now_ms = chrono::Utc::now().timestamp_millis();
    sqlx::query(
        r#"
        INSERT INTO public.app_asset (id, project_id, numeric_id, name, asset_type, create_time_ms, metadata)
        VALUES ($1, $2, $3, $4, 'role', $5, '{}'::jsonb)
        "#,
    )
    .bind(asset_id)
    .bind(project_id)
    .bind(asset_numeric_id)
    .bind(format!("cancel_probe_asset_{}", Uuid::new_v4()))
    .bind(now_ms)
    .execute(&pool)
    .await
    .expect("insert app_asset");

    let image_id = Uuid::new_v4();
    let numeric_image_id = 7_700_001_i32;
    sqlx::query(
        r#"
        INSERT INTO public.app_asset_image (id, asset_id, sort_index, file_path, state, numeric_image_id, metadata)
        VALUES ($1, $2, 0, $3, '生成中', $4, '{"seed":"cancel_roundtrip"}'::jsonb)
        "#,
    )
    .bind(image_id)
    .bind(asset_id)
    .bind("https://example.com/cancel-probe.png")
    .bind(numeric_image_id)
    .execute(&pool)
    .await
    .expect("insert app_asset_image");

    let single_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job (id, owner_user_id, kind, status, payload)
        VALUES ($1, $2, 'asset.generate.image', 'queued', $3::jsonb)
        "#,
    )
    .bind(single_job_id)
    .bind(sub)
    .bind(
        serde_json::json!({
            "source": "pg_contract.assets_generate.cancel.single",
            "project_numeric_id": numeric_id,
            "asset_numeric_id": asset_numeric_id
        })
        .to_string(),
    )
    .execute(&pool)
    .await
    .expect("insert linked single job");

    let batch_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job (id, owner_user_id, kind, status, payload)
        VALUES ($1, $2, 'asset.generate.batch', 'running', $3::jsonb)
        "#,
    )
    .bind(batch_job_id)
    .bind(sub)
    .bind(
        serde_json::json!({
            "source": "pg_contract.assets_generate.cancel.batch",
            "project_numeric_id": numeric_id,
            "items": [
                { "asset_numeric_id": asset_numeric_id, "name": "probe", "prompt": "probe" }
            ]
        })
        .to_string(),
    )
    .execute(&pool)
    .await
    .expect("insert linked batch job");

    let unrelated_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job (id, owner_user_id, kind, status, payload)
        VALUES ($1, $2, 'asset.generate.image', 'queued', $3::jsonb)
        "#,
    )
    .bind(unrelated_job_id)
    .bind(sub)
    .bind(
        serde_json::json!({
            "source": "pg_contract.assets_generate.cancel.unrelated",
            "project_numeric_id": numeric_id,
            "asset_numeric_id": asset_numeric_id + 999
        })
        .to_string(),
    )
    .execute(&pool)
    .await
    .expect("insert unrelated job");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets-generate/cancel-generate")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":{numeric_image_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "cancel body={body}");
    assert_eq!(body["message"].as_str(), Some("取消成功"));

    let row: Option<(Option<String>, serde_json::Value)> =
        sqlx::query_as(r#"SELECT state, metadata FROM public.app_asset_image WHERE id = $1"#)
            .bind(image_id)
            .fetch_optional(&pool)
            .await
            .expect("read app_asset_image after cancel");
    let (state, metadata) = row.expect("cancelled image row exists");
    assert_eq!(state.as_deref(), Some("生成失败"));
    assert_eq!(metadata["cancelled"].as_bool(), Some(true));
    assert_eq!(
        metadata["cancel_source"].as_str(),
        Some("workbench.assets-generate.cancel-generate")
    );

    let single_after: Option<(String, Option<serde_json::Value>)> = sqlx::query_as(
        r#"SELECT status::text, result FROM public.app_generation_job WHERE id = $1"#,
    )
    .bind(single_job_id)
    .fetch_optional(&pool)
    .await
    .expect("read linked single job");
    let (single_status, single_result) = single_after.expect("linked single job exists");
    assert_eq!(single_status, "cancelled");
    assert_eq!(
        single_result
            .as_ref()
            .and_then(|v| v.get("cancel_source"))
            .and_then(serde_json::Value::as_str),
        Some("workbench.assets-generate.cancel-generate")
    );

    let batch_after: Option<(String, Option<serde_json::Value>)> = sqlx::query_as(
        r#"SELECT status::text, result FROM public.app_generation_job WHERE id = $1"#,
    )
    .bind(batch_job_id)
    .fetch_optional(&pool)
    .await
    .expect("read linked batch job");
    let (batch_status, batch_result) = batch_after.expect("linked batch job exists");
    assert_eq!(batch_status, "cancelled");
    assert_eq!(
        batch_result
            .as_ref()
            .and_then(|v| v.get("cancel_numeric_image_id"))
            .and_then(serde_json::Value::as_i64),
        Some(i64::from(numeric_image_id))
    );

    let unrelated_after: Option<String> =
        sqlx::query_scalar(r#"SELECT status::text FROM public.app_generation_job WHERE id = $1"#)
            .bind(unrelated_job_id)
            .fetch_optional(&pool)
            .await
            .expect("read unrelated job");
    assert_eq!(unrelated_after.as_deref(), Some("queued"));

    let res = app
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/projects/{project_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NO_CONTENT);
}
