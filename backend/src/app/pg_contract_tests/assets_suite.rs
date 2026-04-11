use super::*;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn asset_image_file_local_storage_roundtrip() {
    use base64::Engine;
    use serde_json::json;

    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let tmp = tempfile::tempdir().expect("tempdir");
    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let user_dir = tmp.path().join(sub.to_string());
    std::fs::create_dir_all(&user_dir).expect("mkdir user image dir");

    let img_id = Uuid::new_v4();
    let png = base64::engine::general_purpose::STANDARD
        .decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
        .expect("1x1 png");
    std::fs::write(user_dir.join(format!("{img_id}.png")), &png).expect("write png");

    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state_with_local_dir(
        pool.clone(),
        secret.clone(),
        tmp.path().to_path_buf(),
    ));

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
    let _legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;
    let project_uuid = created["id"].as_str().expect("project uuid");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"name":"pg_contract_local_png_asset","type":"role"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, asset_row) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "asset={asset_row}");
    let asset_leg = asset_row["legacy_id"].as_i64().expect("asset legacy_id") as i32;
    let asset_id = Uuid::parse_str(asset_row["id"].as_str().expect("asset id")).unwrap();

    let api_file_path =
        format!("/api/v1/projects/{project_uuid}/assets/{asset_leg}/images/{img_id}/file");
    let meta = json!({"storage": "local", "source": "pg_contract"});
    sqlx::query(
        r#"
        INSERT INTO app_asset_image (id, asset_id, sort_index, file_path, state, metadata)
        VALUES ($1, $2, 0, $3, '已完成', $4)
        "#,
    )
    .bind(img_id)
    .bind(asset_id)
    .bind(&api_file_path)
    .bind(Json(meta))
    .execute(&pool)
    .await
    .expect("insert app_asset_image row");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/{asset_leg}/images/{img_id}/file"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let cache_control = res
        .headers()
        .get(header::CACHE_CONTROL)
        .and_then(|v| v.to_str().ok())
        .map(str::to_string);
    let (status, body, ct) = read_bytes_response(res, 512 * 1024).await;
    assert_eq!(status, StatusCode::OK, "file GET");
    assert_eq!(body, png);
    assert!(
        ct.as_deref()
            .is_some_and(|s| s.to_lowercase().starts_with("image/png")),
        "content-type: {ct:?}"
    );
    assert_eq!(
        cache_control.as_deref(),
        Some("private, max-age=300"),
        "cache-control: {cache_control:?}"
    );

    let res = app
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/projects/{project_uuid}"))
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

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_generate_enqueue_four_kinds() {
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
    let legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;
    let _project_uuid = created["id"].as_str().expect("project uuid");

    let gen_body = format!(
        r#"{{"projectId":{legacy_id},"model":"1:pg_ag","resolution":"1024x1024","id":1,"type":"role","name":"pg_ag_gen","prompt":"probe","base64":"QUJDRA=="}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets-generate/generate")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(gen_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "generate body={job}");
    assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_GENERATE_IMAGE));
    assert_eq!(job["status"].as_str(), Some("queued"));
    assert_eq!(job["payload"]["has_base64"].as_bool(), Some(true));
    assert_eq!(
        job["payload"]["image_base64"].as_str(),
        Some("data:image/jpeg;base64,QUJDRA==")
    );

    let pol_body = format!(
        r#"{{"assetsId":1,"projectId":{legacy_id},"type":"role","name":"n","describe":"d"}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets-generate/polish-prompt")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(pol_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "polish body={job}");
    assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_POLISH_PROMPT));
    assert_eq!(job["status"].as_str(), Some("queued"));

    let bat_gen = format!(
        r#"{{"projectId":{legacy_id},"model":"1:x","resolution":"1024x1024","items":[{{"id":1,"type":"role","name":"n","prompt":"p","base64":"data:image/png;base64,AA=="}}]}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets-generate/batch-generate")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(bat_gen))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "batch-generate body={job}");
    assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_GENERATE_BATCH));
    assert_eq!(job["status"].as_str(), Some("queued"));
    assert_eq!(
        job["payload"]["items"][0]["has_base64"].as_bool(),
        Some(true)
    );
    assert_eq!(
        job["payload"]["items"][0]["image_base64"].as_str(),
        Some("data:image/png;base64,AA==")
    );

    let bat_pol = format!(
        r#"{{"projectId":{legacy_id},"items":[{{"assetsId":1,"type":"role","name":"n","describe":"d"}}]}}"#
    );
    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets-generate/batch-polish")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(bat_pol))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "batch-polish body={job}");
    assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_POLISH_BATCH));
    assert_eq!(job["status"].as_str(), Some("queued"));
}

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
    let legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

    let project_id: Uuid = sqlx::query_scalar(
        r#"SELECT id FROM public.app_project WHERE legacy_id = $1 AND owner_user_id = $2"#,
    )
    .bind(legacy_id)
    .bind(sub)
    .fetch_one(&pool)
    .await
    .expect("project uuid by legacy");

    let asset_id = Uuid::new_v4();
    let asset_legacy_id = 7_000_001_i32;
    let now_ms = chrono::Utc::now().timestamp_millis();
    sqlx::query(
        r#"
        INSERT INTO public.app_asset (id, project_id, legacy_id, name, asset_type, create_time_ms, metadata)
        VALUES ($1, $2, $3, $4, 'role', $5, '{}'::jsonb)
        "#,
    )
    .bind(asset_id)
    .bind(project_id)
    .bind(asset_legacy_id)
    .bind(format!("cancel_probe_asset_{}", Uuid::new_v4()))
    .bind(now_ms)
    .execute(&pool)
    .await
    .expect("insert app_asset");

    let image_id = Uuid::new_v4();
    let legacy_image_id = 7_700_001_i32;
    sqlx::query(
        r#"
        INSERT INTO public.app_asset_image (id, asset_id, sort_index, file_path, state, legacy_image_id, metadata)
        VALUES ($1, $2, 0, $3, '生成中', $4, '{"seed":"cancel_roundtrip"}'::jsonb)
        "#,
    )
    .bind(image_id)
    .bind(asset_id)
    .bind("https://example.com/cancel-probe.png")
    .bind(legacy_image_id)
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
            "project_legacy_id": legacy_id,
            "asset_legacy_id": asset_legacy_id
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
            "project_legacy_id": legacy_id,
            "items": [
                { "asset_legacy_id": asset_legacy_id, "name": "probe", "prompt": "probe" }
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
            "project_legacy_id": legacy_id,
            "asset_legacy_id": asset_legacy_id + 999
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
                .body(Body::from(format!(r#"{{"id":{legacy_image_id}}}"#)))
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
        Some("legacy.assets-generate.cancel-generate")
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
        Some("legacy.assets-generate.cancel-generate")
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
            .and_then(|v| v.get("cancel_legacy_image_id"))
            .and_then(serde_json::Value::as_i64),
        Some(i64::from(legacy_image_id))
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

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_upload_clip_roundtrip() {
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
    let project_legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

    let clip_name = format!("pg_clip_{}", Uuid::new_v4());
    let body = format!(
        r#"{{"projectId":{project_legacy_id},"name":"{clip_name}","base64Data":"QUJDRA=="}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/upload-clip")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, uploaded) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "uploaded={uploaded}");
    assert_eq!(uploaded["message"].as_str(), Some("上传成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/get-material-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_legacy_id}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, material) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "material={material}");
    let row = material["data"]
        .as_array()
        .expect("material.data")
        .iter()
        .find(|r| r["name"].as_str() == Some(clip_name.as_str()))
        .expect("uploaded clip row");
    assert_eq!(row["type"].as_str(), Some("clip"));
    assert_eq!(
        row["filePath"].as_str(),
        Some("data:application/octet-stream;base64,QUJDRA==")
    );

    let clip_legacy_id = row["id"].as_i64().expect("clip legacy id") as i32;
    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/get-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"assetsId":{clip_legacy_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, image_bundle) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "image_bundle={image_bundle}");
    assert_eq!(
        image_bundle["imageId"].as_i64(),
        image_bundle["tempAssets"][0]["id"].as_i64()
    );
    assert_eq!(
        image_bundle["tempAssets"][0]["selected"].as_bool(),
        Some(true)
    );
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_legacy_mutation_endpoints_roundtrip() {
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
    let project_legacy_id = created_project["legacy_id"]
        .as_i64()
        .expect("project legacy id") as i32;
    let project_uuid = created_project["id"].as_str().expect("project uuid");

    let base_name = format!("pg_legacy_asset_{}", Uuid::new_v4().simple());
    let asset_a_name = format!("{base_name}_a");
    let asset_b_name = format!("{base_name}_b");
    let asset_c_name = format!("{base_name}_c");
    let asset_d_name = format!("{base_name}_d");

    let create_body = format!(
        r#"{{"name":"{asset_a_name}","describe":"desc a","type":"role","projectId":{project_legacy_id},"remark":"  r0  ","prompt":"  p0  "}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/add-assets")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(create_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, add_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "add_msg={add_msg}");
    assert_eq!(add_msg["message"].as_str(), Some("新增资产成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets?name={asset_a_name}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_a) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list_a={list_a}");
    assert_eq!(list_a["total"].as_i64(), Some(1));
    let asset_a_legacy_id = list_a["items"][0]["legacy_id"]
        .as_i64()
        .expect("asset_a legacy id") as i32;
    assert_eq!(
        list_a["items"][0]["metadata"]["prompt"].as_str(),
        Some("p0"),
        "prompt should be trimmed on add-assets"
    );
    assert_eq!(
        list_a["items"][0]["metadata"]["remark"].as_str(),
        Some("r0"),
        "remark should be trimmed on add-assets"
    );

    let save_body = format!(
        r#"{{"id":{asset_a_legacy_id},"projectId":{project_legacy_id},"type":"role","prompt":"  p1  ","base64":"QUJDRA=="}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/save-assets")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(save_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, save_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "save_msg={save_msg}");
    assert_eq!(save_msg["message"].as_str(), Some("保存资产图片成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/get-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"assetsId":{asset_a_legacy_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, get_image) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get_image={get_image}");
    let image_legacy_id = get_image["imageId"].as_i64().expect("imageId") as i32;
    assert_eq!(
        get_image["tempAssets"]
            .as_array()
            .map(|arr| arr.len())
            .unwrap_or(0),
        1
    );
    assert_eq!(get_image["tempAssets"][0]["selected"].as_bool(), Some(true));

    let update_body = format!(
        r#"{{"id":{asset_a_legacy_id},"name":"{asset_a_name}_u","describe":"desc a2","remark":"  r2  ","prompt":"   "}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/update-assets")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(update_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, update_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "update_msg={update_msg}");
    assert_eq!(update_msg["message"].as_str(), Some("更新资产成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/{asset_a_legacy_id}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, asset_after_update) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "asset_after_update={asset_after_update}"
    );
    assert_eq!(
        asset_after_update["name"].as_str(),
        Some(format!("{asset_a_name}_u").as_str())
    );
    assert_eq!(asset_after_update["description"].as_str(), Some("desc a2"));
    assert!(
        asset_after_update["metadata"]["prompt"].is_null(),
        "blank prompt should clear metadata.prompt"
    );
    assert_eq!(
        asset_after_update["metadata"]["remark"].as_str(),
        Some("r2")
    );
    assert_eq!(
        asset_after_update["metadata"]["imageId"].as_i64(),
        Some(i64::from(image_legacy_id))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/del-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":{image_legacy_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, del_image_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "del_image_msg={del_image_msg}");
    assert_eq!(del_image_msg["message"].as_str(), Some("资产图片删除成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/get-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"assetsId":{asset_a_legacy_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, image_after_delete) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "image_after_delete={image_after_delete}"
    );
    assert!(image_after_delete["imageId"].is_null());
    assert!(image_after_delete["tempAssets"]
        .as_array()
        .is_some_and(|arr| arr.is_empty()));

    for name in [&asset_b_name, &asset_c_name, &asset_d_name] {
        let create_body = format!(
            r#"{{"name":"{name}","describe":"desc","type":"role","projectId":{project_legacy_id}}}"#
        );
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/assets/add-assets")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(create_body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, add_msg) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "add_msg={add_msg}");
    }

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets?name={asset_b_name}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_b) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list_b={list_b}");
    let asset_b_legacy_id = list_b["items"][0]["legacy_id"]
        .as_i64()
        .expect("asset_b legacy id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/del-assets")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":{asset_b_legacy_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, del_asset_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "del_asset_msg={del_asset_msg}");
    assert_eq!(del_asset_msg["message"].as_str(), Some("删除资产成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets?name={asset_c_name}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_c) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list_c={list_c}");
    assert_eq!(list_c["total"].as_i64(), Some(1), "list_c={list_c}");
    let asset_c_legacy_id = list_c["items"][0]["legacy_id"]
        .as_i64()
        .expect("asset_c legacy id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets?name={asset_d_name}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_d) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list_d={list_d}");
    assert_eq!(list_d["total"].as_i64(), Some(1), "list_d={list_d}");
    let asset_d_legacy_id = list_d["items"][0]["legacy_id"]
        .as_i64()
        .expect("asset_d legacy id") as i32;

    let batch_delete_body = format!(r#"{{"id":[{asset_c_legacy_id},{asset_d_legacy_id}]}}"#);
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/batch-delete")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(batch_delete_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, batch_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "batch_msg={batch_msg}");
    assert_eq!(batch_msg["message"].as_str(), Some("删除资产成功"));

    for name in [&asset_b_name, &asset_c_name, &asset_d_name] {
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/{project_uuid}/assets?name={name}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, list_after_delete) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "list_after_delete={list_after_delete}"
        );
        assert_eq!(list_after_delete["total"].as_i64(), Some(0));
    }
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_get_assets_api_parent_child_roundtrip() {
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
    let project_legacy_id = created_project["legacy_id"]
        .as_i64()
        .expect("project legacy id") as i32;
    let project_uuid = created_project["id"].as_str().expect("project uuid");

    let parent_a_name = format!("pg_parent_a_{}", Uuid::new_v4());
    let parent_b_name = format!("pg_parent_b_{}", Uuid::new_v4());
    let child_a_name = format!("pg_child_a_{}", Uuid::new_v4());
    let child_b_name = format!("pg_child_b_{}", Uuid::new_v4());

    let (status, parent_a) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{parent_a_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "parent_a={parent_a}");
    let parent_a_legacy_id = parent_a["legacy_id"].as_i64().expect("parent_a legacy id") as i32;

    let (status, parent_b) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{parent_b_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "parent_b={parent_b}");
    let parent_b_legacy_id = parent_b["legacy_id"].as_i64().expect("parent_b legacy id") as i32;

    let (status, child_a) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{child_a_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "child_a={child_a}");
    let child_a_legacy_id = child_a["legacy_id"].as_i64().expect("child_a legacy id") as i32;

    let (status, child_b) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{child_b_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "child_b={child_b}");
    let child_b_legacy_id = child_b["legacy_id"].as_i64().expect("child_b legacy id") as i32;

    let parent_a_uuid: Uuid = sqlx::query_scalar(
        r#"SELECT id
           FROM app_asset
           WHERE project_id = (SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $2)
             AND legacy_id = $3"#,
    )
    .bind(project_legacy_id)
    .bind(sub)
    .bind(parent_a_legacy_id)
    .fetch_one(&pool)
    .await
    .expect("parent_a uuid");

    sqlx::query(
        r#"
        UPDATE app_asset
        SET metadata = jsonb_set(
          jsonb_set(COALESCE(metadata, '{}'::jsonb), '{projectId}', to_jsonb($1::integer), true),
          '{assetsId}',
          to_jsonb($2::integer),
          true
        )
        WHERE project_id = (SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $3)
          AND legacy_id = $4
        "#,
    )
    .bind(project_legacy_id)
    .bind(parent_a_legacy_id)
    .bind(sub)
    .bind(child_a_legacy_id)
    .execute(&pool)
    .await
    .expect("child_a metadata.assetsId");

    sqlx::query(
        r#"
        UPDATE app_asset
        SET metadata = jsonb_set(
          jsonb_set(COALESCE(metadata, '{}'::jsonb), '{projectId}', to_jsonb($1::integer), true),
          '{assetsId}',
          to_jsonb($2::integer),
          true
        )
        WHERE project_id = (SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $3)
          AND legacy_id = $4
        "#,
    )
    .bind(project_legacy_id)
    .bind(parent_b_legacy_id)
    .bind(sub)
    .bind(child_b_legacy_id)
    .execute(&pool)
    .await
    .expect("child_b metadata.assetsId");

    let parent_a_image_legacy_id = 9_901_001;
    sqlx::query(
        r#"
        UPDATE app_asset
        SET metadata = jsonb_set(
          jsonb_set(COALESCE(metadata, '{}'::jsonb), '{projectId}', to_jsonb($1::integer), true),
          '{imageId}',
          to_jsonb($2::integer),
          true
        )
        WHERE project_id = (SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $3)
          AND legacy_id = $4
        "#,
    )
    .bind(project_legacy_id)
    .bind(parent_a_image_legacy_id)
    .bind(sub)
    .bind(parent_a_legacy_id)
    .execute(&pool)
    .await
    .expect("parent_a metadata.imageId");

    sqlx::query(
        r#"
        INSERT INTO app_asset_image (asset_id, sort_index, file_path, state, legacy_image_id, metadata)
        VALUES ($1, 0, '/tmp/pg_parent_a_selected.png', '失败', $2, '{"errorReason":"provider_timeout"}'::jsonb)
        "#,
    )
    .bind(parent_a_uuid)
    .bind(parent_a_image_legacy_id)
    .execute(&pool)
    .await
    .expect("insert parent_a selected image");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/get-assets-api")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_legacy_id},"type":"role","page":1,"limit":1}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, first_page) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "first_page={first_page}");
    assert_eq!(first_page["total"].as_i64(), Some(2));
    let rows = first_page["data"].as_array().expect("first page data");
    assert_eq!(rows.len(), 1);
    let first_parent = &rows[0];
    assert_eq!(
        first_parent["id"].as_i64(),
        Some(i64::from(parent_a_legacy_id))
    );
    assert_eq!(
        first_parent["filePath"].as_str(),
        Some("/tmp/pg_parent_a_selected.png")
    );
    assert_eq!(
        first_parent["src"].as_str(),
        Some("/tmp/pg_parent_a_selected.png")
    );
    assert_eq!(first_parent["state"].as_str(), Some("失败"));
    assert_eq!(
        first_parent["errorReason"].as_str(),
        Some("provider_timeout")
    );
    let first_children = first_parent["sonAssets"]
        .as_array()
        .expect("first parent sonAssets");
    assert_eq!(first_children.len(), 1);
    assert_eq!(
        first_children[0]["id"].as_i64(),
        Some(i64::from(child_a_legacy_id))
    );
    assert_eq!(
        first_children[0]["assetsId"].as_i64(),
        Some(i64::from(parent_a_legacy_id))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/get-assets-api")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_legacy_id},"type":"role","page":2,"limit":1}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, second_page) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "second_page={second_page}");
    assert_eq!(second_page["total"].as_i64(), Some(2));
    let rows = second_page["data"].as_array().expect("second page data");
    assert_eq!(rows.len(), 1);
    let second_parent = &rows[0];
    assert_eq!(
        second_parent["id"].as_i64(),
        Some(i64::from(parent_b_legacy_id))
    );
    let second_children = second_parent["sonAssets"]
        .as_array()
        .expect("second parent sonAssets");
    assert_eq!(second_children.len(), 1);
    assert_eq!(
        second_children[0]["id"].as_i64(),
        Some(i64::from(child_b_legacy_id))
    );
    assert_eq!(
        second_children[0]["assetsId"].as_i64(),
        Some(i64::from(parent_b_legacy_id))
    );
}

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
    let project_legacy_id = created_project["legacy_id"]
        .as_i64()
        .expect("project legacy id") as i32;
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
    let ready_asset_legacy_id = ready_asset["legacy_id"]
        .as_i64()
        .expect("ready asset legacy id") as i32;

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
    let running_asset_legacy_id = running_asset["legacy_id"]
        .as_i64()
        .expect("running asset legacy id") as i32;

    let ready_asset_uuid: Uuid = sqlx::query_scalar(
        r#"SELECT id
           FROM app_asset
           WHERE project_id = (SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $2)
             AND legacy_id = $3"#,
    )
    .bind(project_legacy_id)
    .bind(sub)
    .bind(ready_asset_legacy_id)
    .fetch_one(&pool)
    .await
    .expect("ready asset uuid");
    let running_asset_uuid: Uuid = sqlx::query_scalar(
        r#"SELECT id
           FROM app_asset
           WHERE project_id = (SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $2)
             AND legacy_id = $3"#,
    )
    .bind(project_legacy_id)
    .bind(sub)
    .bind(running_asset_legacy_id)
    .fetch_one(&pool)
    .await
    .expect("running asset uuid");

    let ready_image_legacy_id = 9_902_001;
    let running_image_legacy_id = 9_902_002;

    sqlx::query(
        r#"
        UPDATE app_asset
        SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{imageId}', to_jsonb($1::integer), true)
        WHERE id = $2
        "#,
    )
    .bind(ready_image_legacy_id)
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
    .bind(running_image_legacy_id)
    .bind(running_asset_uuid)
    .execute(&pool)
    .await
    .expect("set running imageId");

    sqlx::query(
        r#"
        INSERT INTO app_asset_image (asset_id, sort_index, file_path, state, legacy_image_id)
        VALUES
          ($1, 0, '/tmp/pg_polling_ready.png', '已完成', $2),
          ($3, 0, '/tmp/pg_polling_running.png', '生成中', $4)
        "#,
    )
    .bind(ready_asset_uuid)
    .bind(ready_image_legacy_id)
    .bind(running_asset_uuid)
    .bind(running_image_legacy_id)
    .execute(&pool)
    .await
    .expect("insert selected images");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/polling-image-assets")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"ids":[{ready_asset_legacy_id},{running_asset_legacy_id}]}}"#
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
        Some(i64::from(ready_asset_legacy_id))
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
                    r#"{{"kind":"{JOB_KIND_ASSET_POLISH_PROMPT}","payload":{{"asset_legacy_id":{ready_asset_legacy_id}}}}}"#
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
                    r#"{{"kind":"{JOB_KIND_ASSET_POLISH_PROMPT}","payload":{{"asset_legacy_id":{running_asset_legacy_id}}}}}"#
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
                .uri("/api/v1/assets/polling-prompt-assets")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"ids":[{ready_asset_legacy_id},{running_asset_legacy_id}]}}"#
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
        Some(i64::from(ready_asset_legacy_id))
    );
    assert_eq!(rows[0]["promptState"].as_str(), Some("失败"));
    assert_eq!(rows[0]["name"].as_str(), Some(ready_asset_name.as_str()));
    assert_eq!(rows[0]["type"].as_str(), Some("role"));
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_batch_generation_data_filters_roundtrip() {
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
    let project_legacy_id = created_project["legacy_id"]
        .as_i64()
        .expect("project legacy id") as i32;
    let project_uuid = created_project["id"].as_str().expect("project uuid");

    let make_asset = |name: &str, kind: &str| -> Request<Body> {
        Request::builder()
            .method(Method::POST)
            .uri(format!("/api/v1/projects/{project_uuid}/assets"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(format!(
                r#"{{"name":"{name}","type":"{kind}"}}"#
            )))
            .unwrap()
    };

    let role_name_a = format!("pg_batch_role_a_{}", Uuid::new_v4());
    let role_name_b = format!("pg_batch_role_b_{}", Uuid::new_v4());
    let scene_name = format!("pg_batch_scene_{}", Uuid::new_v4());

    let (status, _) = read_json_response(
        app.clone()
            .oneshot(make_asset(&role_name_a, "role"))
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "create role a");
    let (status, _) = read_json_response(
        app.clone()
            .oneshot(make_asset(&role_name_b, "role"))
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "create role b");
    let (status, _) = read_json_response(
        app.clone()
            .oneshot(make_asset(&scene_name, "scene"))
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "create scene");

    let filter_body = format!(
        r#"{{"projectId":{project_legacy_id},"type":"role","name":"role_","page":1,"limit":1}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/batch-generation-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(filter_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, page_1) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "page_1={page_1}");
    assert_eq!(page_1["total"].as_i64(), Some(2));
    assert_eq!(page_1["data"].as_array().expect("page_1.data").len(), 1);
    let first_name = page_1["data"][0]["name"]
        .as_str()
        .expect("page_1 first name")
        .to_string();
    assert!(first_name == role_name_a || first_name == role_name_b);
    assert_eq!(page_1["data"][0]["type"].as_str(), Some("role"));

    let filter_body_page_2 = format!(
        r#"{{"projectId":{project_legacy_id},"type":"role","name":"role_","page":2,"limit":1}}"#
    );
    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/batch-generation-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(filter_body_page_2))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, page_2) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "page_2={page_2}");
    assert_eq!(page_2["total"].as_i64(), Some(2));
    assert_eq!(page_2["data"].as_array().expect("page_2.data").len(), 1);
    let second_name = page_2["data"][0]["name"]
        .as_str()
        .expect("page_2 first name");
    assert!(second_name == role_name_a || second_name == role_name_b);
    assert_ne!(first_name, second_name);
    assert_eq!(page_2["data"][0]["type"].as_str(), Some("role"));
}
