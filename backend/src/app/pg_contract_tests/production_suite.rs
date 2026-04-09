use super::*;
use std::io::Cursor;
use zip::ZipArchive;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
async fn production_legacy_endpoints_minimal_roundtrip() {
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

    // Create project, script, and storyboard for testing
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

    // Create script
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/legacy/{project_id}/scripts"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, script) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "script={script}");
    let script_id = script["legacy_id"].as_i64().expect("script legacy_id") as i32;

    // Test get-production-data (empty ids should fail)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/get-production-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"ids":[]}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "empty ids should fail");

    // Test get-flow-data (minimal implementation)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/get-flow-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{},"episodesId":1}}"#,
                    project_id
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    // Returns 404 because no storyboards exist yet
    assert_eq!(status, StatusCode::NOT_FOUND, "no storyboards yet");

    // Test save-flow-data (minimal implementation)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/save-flow-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{},"episodesId":1,"data":{{}}}}"#,
                    project_id
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    // Returns 404 because no storyboards exist yet
    assert_eq!(status, StatusCode::NOT_FOUND, "no storyboards yet");

    // Test workbench/generate-video (minimal implementation)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/workbench/generate-video")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{},"scriptId":{},"uploadData":[],"prompt":"test","model":"test","mode":"test","resolution":"720p","duration":5,"trackId":1}}"#,
                    project_id, script_id
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    // Returns 200 because project/script ownership is verified
    assert_eq!(status, StatusCode::OK, "generate-video minimal ok");

    // Test storyboard/polling-image (empty ids should fail)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/storyboard/polling-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"ids":[]}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "empty ids should fail");

    // Test export-image (empty shot_id should fail)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/export-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"shotId":[]}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "empty shotId should fail");

    // Test workbench/get-video-list (implemented; empty list is fine)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/workbench/get-video-list")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get-video-list should return 200");
    assert_eq!(body["total"].as_i64(), Some(0));

    // Test edit-image/upload-image (legacy parity): validates ownership + returns normalized data URI
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/edit-image/upload-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"base64Data":"data:image/png;base64,AA=="}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "upload-image should return 200");
    assert_eq!(body["url"].as_str(), Some("data:image/png;base64,AA=="));

    // Cleanup
    let _ = sqlx::query("DELETE FROM public.app_script WHERE project_id IN (SELECT id FROM public.app_project WHERE legacy_id = $1)")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test settings_agent_deploy_roundtrip -- --ignored"]
async fn settings_agent_deploy_roundtrip() {
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
                .uri("/api/v1/settings/agent-deploy/list")
                .method(Method::POST)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, before) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "before={before}");
    assert_eq!(before[0]["key"].as_str(), Some("scriptAgent"));
    assert_eq!(before[0]["model"].as_str(), Some(""));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/agent-deploy/deploy-model")
                .method(Method::POST)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"id":1,"name":"剧本Agent","model":"gpt-4.1","modelName":"GPT-4.1","vendorId":"openai","desc":"probe"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, saved) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "saved={saved}");
    assert_eq!(saved["key"].as_str(), Some("scriptAgent"));
    assert_eq!(saved["message"].as_str(), Some("保存成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/agent-deploy/list")
                .method(Method::POST)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, after) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "after={after}");
    assert_eq!(after[0]["model"].as_str(), Some("gpt-4.1"));
    assert_eq!(after[0]["modelName"].as_str(), Some("GPT-4.1"));
    assert_eq!(after[0]["vendorId"].as_str(), Some("openai"));

    let stored: Option<Value> = sqlx::query_scalar(
        r#"
        SELECT agent_deploy_config
        FROM public.app_user_profile
        WHERE user_id = $1
        "#,
    )
    .bind(sub)
    .fetch_optional(&pool)
    .await
    .expect("select agent_deploy_config");
    let stored = stored.expect("stored agent_deploy_config");
    assert_eq!(
        stored["rows"]["scriptAgent"]["model"].as_str(),
        Some("gpt-4.1")
    );

    let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn production_workbench_video_roundtrip() {
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
                .uri(format!("/api/v1/projects/legacy/{project_id}/scripts"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"name":"pg_video_script"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, script) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "script={script}");
    let script_id = script["legacy_id"].as_i64().expect("script legacy_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/scripts/legacy/{script_id}/storyboards"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"prompt":"pg_video_storyboard","duration":"5","track_id":7,"flow_id":21,"sb_index":1}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, storyboard) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "storyboard={storyboard}");
    let storyboard_id = storyboard["legacy_id"]
        .as_i64()
        .expect("storyboard legacy_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/scripts/legacy/{script_id}/storyboards"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"prompt":"pg_video_storyboard_two","duration":"6","track_id":9,"flow_id":22,"sb_index":2}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, storyboard_two) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CREATED,
        "storyboard_two={storyboard_two}"
    );
    let storyboard_two_id = storyboard_two["legacy_id"]
        .as_i64()
        .expect("storyboard_two legacy_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/get-production-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"ids":[{storyboard_id}]}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, production_data) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "production_data={production_data}");
    assert_eq!(
        production_data["data"][0]["id"].as_i64(),
        Some(i64::from(storyboard_id))
    );
    assert_eq!(
        production_data["data"][0]["trackId"].as_i64(),
        Some(7),
        "storyboard create should persist track"
    );
    assert_eq!(
        production_data["data"][0]["flowId"].as_i64(),
        Some(21),
        "storyboard create should persist flow"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/get-flow-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"episodesId":{script_id}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, initial_flow_data) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "initial_flow_data={initial_flow_data}"
    );
    assert_eq!(
        initial_flow_data["script"].as_str(),
        Some(""),
        "default flow should expose script content"
    );
    assert_eq!(
        initial_flow_data["storyboard"].as_array().map(Vec::len),
        Some(2)
    );
    assert_eq!(
        initial_flow_data["storyboard"][0]["id"].as_i64(),
        Some(i64::from(storyboard_id))
    );
    assert_eq!(
        initial_flow_data["storyboard"][1]["id"].as_i64(),
        Some(i64::from(storyboard_two_id))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/save-flow-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    serde_json::json!({
                        "projectId": project_id,
                        "episodesId": script_id,
                        "data": {
                            "scriptPlan": "plan-v1",
                            "storyboardTable": "table-v1",
                            "storyboard": [
                                {"id": storyboard_two_id, "associateAssetsIds": [11, 12]},
                                {"id": storyboard_id, "associateAssetsIds": [21]},
                            ],
                            "extraPanel": {"zoom": 125},
                        }
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(
        res.status(),
        StatusCode::OK,
        "save-flow-data should accept owned project"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/get-flow-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"episodesId":{script_id}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, saved_flow_data) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "saved_flow_data={saved_flow_data}");
    assert_eq!(saved_flow_data["scriptPlan"].as_str(), Some("plan-v1"));
    assert_eq!(
        saved_flow_data["storyboardTable"].as_str(),
        Some("table-v1")
    );
    assert_eq!(saved_flow_data["extraPanel"]["zoom"].as_i64(), Some(125));
    assert_eq!(
        saved_flow_data["storyboard"][0]["id"].as_i64(),
        Some(i64::from(storyboard_two_id)),
        "saved storyboard order should drive later get-flow-data ordering"
    );
    assert_eq!(
        saved_flow_data["storyboard"][0]["associateAssetsIds"][0].as_i64(),
        Some(11)
    );
    assert_eq!(
        saved_flow_data["storyboard"][1]["id"].as_i64(),
        Some(i64::from(storyboard_id))
    );
    let reordered_indexes: Vec<(i32, Option<i32>)> = sqlx::query_as(
        r#"
        SELECT legacy_id, sb_index
        FROM app_storyboard
        WHERE legacy_id = ANY($1::int4[])
        ORDER BY legacy_id ASC
        "#,
    )
    .bind(vec![storyboard_id, storyboard_two_id])
    .fetch_all(&pool)
    .await
    .expect("query reordered storyboard indexes");
    assert_eq!(
        reordered_indexes,
        vec![(storyboard_id, Some(1)), (storyboard_two_id, Some(0))]
    );

    let storyboard_data_uri =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a8Z8AAAAASUVORK5CYII=";
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/storyboard/update-url")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"storyboardId":{storyboard_id},"imageUrl":"{storyboard_data_uri}"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, updated_storyboard) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "updated_storyboard={updated_storyboard}"
    );
    assert_eq!(
        updated_storyboard["imageUrl"].as_str(),
        Some(storyboard_data_uri)
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/storyboard/polling-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"ids":[{storyboard_id}]}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(
        res.status(),
        StatusCode::OK,
        "polling-image should accept owned storyboard"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/export-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"shotId":[{{"id":"{storyboard_id}"}}]}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let content_disposition = res
        .headers()
        .get(header::CONTENT_DISPOSITION)
        .and_then(|v| v.to_str().ok())
        .map(str::to_string);
    let (status, body, ct) = read_bytes_response(res, 512 * 1024).await;
    assert_eq!(status, StatusCode::OK, "export-image should return zip");
    assert_eq!(ct.as_deref(), Some("application/zip"));
    assert!(
        content_disposition
            .as_deref()
            .unwrap_or_default()
            .contains("toonflow-storyboards-"),
        "content-disposition={content_disposition:?}"
    );

    let cursor = Cursor::new(body);
    let mut archive = ZipArchive::new(cursor).expect("valid zip");
    assert_eq!(archive.len(), 1, "one storyboard file expected in zip");
    let mut exported = archive.by_index(0).expect("zip first file");
    assert_eq!(exported.name(), format!("storyboard-{storyboard_id}.png"));
    let mut exported_bytes = Vec::new();
    std::io::Read::read_to_end(&mut exported, &mut exported_bytes).expect("read zip entry");
    assert!(
        !exported_bytes.is_empty(),
        "zip entry should contain image bytes"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/workbench/add-track")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"trackName":"B-roll"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, add_track) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "add_track={add_track}");
    assert_eq!(
        add_track["track_id"].as_i64(),
        Some(8),
        "add-track should allocate next track id"
    );
    let persisted_track_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM app_video_track vt
        INNER JOIN app_project p ON p.id = vt.project_id
        INNER JOIN app_script s ON s.id = vt.script_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND s.legacy_id = $3
          AND vt.legacy_id = $4
        "#,
    )
    .bind(sub)
    .bind(project_id)
    .bind(script_id)
    .bind(8_i32)
    .fetch_one(&pool)
    .await
    .expect("query persisted video track");
    assert_eq!(
        persisted_track_count, 1,
        "add-track should persist app_video_track row"
    );

    let selected_video_url = "https://cdn.example.com/pg-contract-video.mp4";
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/workbench/select-video")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"storyboardId":{storyboard_id},"videoUrl":"{selected_video_url}"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, selected) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "selected={selected}");
    assert_eq!(selected["video_url"].as_str(), Some(selected_video_url));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/workbench/get-video-list")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"trackId":7}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, track_videos) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "track_videos={track_videos}");
    assert_eq!(track_videos["total"].as_i64(), Some(1));
    assert_eq!(
        track_videos["videos"][0]["id"].as_i64(),
        Some(i64::from(storyboard_id))
    );
    assert_eq!(
        track_videos["videos"][0]["video_url"].as_str(),
        Some(selected_video_url)
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/workbench/delete-track")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"trackId":7}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, deleted_track) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "deleted_track={deleted_track}");
    assert_eq!(deleted_track["track_id"].as_i64(), Some(7));
    let deleted_track_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM app_video_track vt
        INNER JOIN app_project p ON p.id = vt.project_id
        INNER JOIN app_script s ON s.id = vt.script_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND s.legacy_id = $3
          AND vt.legacy_id = $4
        "#,
    )
    .bind(sub)
    .bind(project_id)
    .bind(script_id)
    .bind(7_i32)
    .fetch_one(&pool)
    .await
    .expect("query deleted video track");
    assert_eq!(
        deleted_track_count, 0,
        "delete-track should remove persisted app_video_track row"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/get-production-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"ids":[{storyboard_id}]}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cleared_track_data) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "cleared_track_data={cleared_track_data}"
    );
    assert!(
        cleared_track_data["data"][0]["trackId"].is_null(),
        "delete-track should clear storyboard track assignment"
    );
    assert_eq!(
        cleared_track_data["data"][0]["url"].as_str(),
        Some(selected_video_url),
        "delete-track must not remove selected video"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/workbench/get-video-list")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"trackId":7}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, filtered_after_delete_track) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "filtered_after_delete_track={filtered_after_delete_track}"
    );
    assert_eq!(filtered_after_delete_track["total"].as_i64(), Some(0));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/workbench/get-video-list")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"projectId":{project_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, all_videos_before_delete_video) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "all_videos_before_delete_video={all_videos_before_delete_video}"
    );
    assert_eq!(all_videos_before_delete_video["total"].as_i64(), Some(1));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/workbench/delete-video")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"storyboardId":{storyboard_id}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, deleted_video) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "deleted_video={deleted_video}");
    assert_eq!(
        deleted_video["storyboard_id"].as_i64(),
        Some(i64::from(storyboard_id))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/get-production-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"ids":[{storyboard_id}]}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, after_delete_video) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "after_delete_video={after_delete_video}"
    );
    assert!(after_delete_video["data"][0]["url"].is_null());
    assert!(after_delete_video["data"][0]["state"].is_null());

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/workbench/get-video-list")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"projectId":{project_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, all_videos_after_delete_video) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "all_videos_after_delete_video={all_videos_after_delete_video}"
    );
    assert_eq!(all_videos_after_delete_video["total"].as_i64(), Some(0));

    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn production_assets_derivative_roundtrip() {
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
                .uri(format!("/api/v1/projects/legacy/{project_id}/assets"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"name":"pg_derivative_asset","type":"role","description":"hero"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, asset) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "asset={asset}");
    let asset_id = asset["legacy_id"].as_i64().expect("asset legacy_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/assets/get-assets-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"assetType":"role","limit":10,"offset":0}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, assets_data) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "assets_data={assets_data}");
    assert_eq!(assets_data["total"].as_i64(), Some(1));
    assert_eq!(
        assets_data["assets"][0]["id"].as_i64(),
        Some(i64::from(asset_id))
    );

    let image_url = "https://cdn.example.com/pg-asset-derivative.png";
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/assets/update-assets-url")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"assetId":{asset_id},"imageUrl":"{image_url}"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, updated_url) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "updated_url={updated_url}");
    assert_eq!(updated_url["asset_id"].as_i64(), Some(i64::from(asset_id)));
    assert_eq!(updated_url["image_url"].as_str(), Some(image_url));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/assets/polling-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"assetIds":[{asset_id}]}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, polling) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "polling={polling}");
    assert_eq!(
        polling["statuses"][0]["asset_id"].as_i64(),
        Some(i64::from(asset_id))
    );
    assert_eq!(polling["statuses"][0]["image_count"].as_i64(), Some(1));
    assert_eq!(
        polling["statuses"][0]["latest_state"].as_str(),
        Some("已完成")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/assets/delete-assets-derivative")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"assetIds":[{asset_id}]}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, deleted) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "deleted={deleted}");
    assert_eq!(deleted["deleted"].as_i64(), Some(1));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/assets/polling-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"assetIds":[{asset_id}]}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, polling_after_delete) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "polling_after_delete={polling_after_delete}"
    );
    assert_eq!(
        polling_after_delete["statuses"][0]["image_count"].as_i64(),
        Some(0)
    );
    assert!(polling_after_delete["statuses"][0]["latest_state"].is_null());

    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}
