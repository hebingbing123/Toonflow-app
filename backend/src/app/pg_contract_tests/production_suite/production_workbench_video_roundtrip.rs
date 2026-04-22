use super::super::*;
use std::io::Cursor;
use tower::ServiceExt;
use zip::ZipArchive;

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
    let project_id = created["numeric_id"].as_i64().expect("numeric_id") as i32;
    let project_uuid = created["id"].as_str().expect("project uuid");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/scripts"))
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
    let script_id = script["numeric_id"].as_i64().expect("script numeric_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/scripts/{script_id}/storyboards"
                ))
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
    let storyboard_id = storyboard["numeric_id"]
        .as_i64()
        .expect("storyboard numeric_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/scripts/{script_id}/storyboards"
                ))
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
    let storyboard_two_id = storyboard_two["numeric_id"]
        .as_i64()
        .expect("storyboard_two numeric_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/get-production-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"ids":[{storyboard_id}]}}"#
                )))
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
        SELECT numeric_id, sb_index
        FROM app_storyboard
        WHERE numeric_id = ANY($1::int4[])
        ORDER BY numeric_id ASC
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
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"storyboardId":{storyboard_id},"imageUrl":"{storyboard_data_uri}"}}"#
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
    sqlx::query(
        r#"
        UPDATE app_storyboard
        SET video_desc = $2, updated_at = NOW()
        WHERE numeric_id = $1
        "#,
    )
    .bind(storyboard_id)
    .bind("旁白：主角抬头看向远方")
    .execute(&pool)
    .await
    .expect("persist storyboard subtitle text");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/storyboard/polling-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"ids":[{storyboard_id}]}}"#
                )))
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
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"shotId":[{{"id":"{storyboard_id}"}}]}}"#
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
    assert_eq!(
        archive.len(),
        7,
        "image + manifest + csv + timeline + subtitles + voiceover script + voiceover segments expected in zip"
    );
    let mut exported = archive
        .by_name(&format!("storyboard-{storyboard_id}.png"))
        .expect("zip storyboard image");
    let mut exported_bytes = Vec::new();
    std::io::Read::read_to_end(&mut exported, &mut exported_bytes).expect("read zip entry");
    assert!(
        !exported_bytes.is_empty(),
        "zip entry should contain image bytes"
    );
    drop(exported);
    let mut manifest_entry = archive.by_name("manifest.json").expect("zip manifest");
    let mut manifest_bytes = Vec::new();
    std::io::Read::read_to_end(&mut manifest_entry, &mut manifest_bytes)
        .expect("read manifest entry");
    let manifest: Value = serde_json::from_slice(&manifest_bytes).expect("manifest json");
    assert_eq!(
        manifest["export_type"].as_str(),
        Some("storyboard_image_bundle")
    );
    assert_eq!(manifest["shot_count"].as_i64(), Some(1));
    assert_eq!(
        manifest["shots"][0]["storyboard_id"].as_i64(),
        Some(i64::from(storyboard_id))
    );
    assert_eq!(
        manifest["shots"][0]["image_filename"].as_str(),
        Some(format!("storyboard-{storyboard_id}.png").as_str())
    );
    assert_eq!(
        manifest["shots"][0]["subtitle_source"].as_str(),
        Some("explicit_narration")
    );
    assert_eq!(
        manifest["shots"][0]["voiceover_ready"].as_bool(),
        Some(true)
    );
    drop(manifest_entry);
    let mut csv_entry = archive
        .by_name("storyboard.csv")
        .expect("zip storyboard csv");
    let mut csv = String::new();
    std::io::Read::read_to_string(&mut csv_entry, &mut csv).expect("read csv entry");
    assert!(csv.starts_with(
        "storyboard_id,order_index,storyboard_index,track_id,duration,state,prompt,subtitle_source,voiceover_ready,image_filename,image_source\n"
    ));
    assert!(csv.contains(&storyboard_id.to_string()));
    assert!(csv.contains("explicit_narration,true"));
    drop(csv_entry);
    let mut timeline_entry = archive.by_name("timeline.json").expect("zip timeline json");
    let mut timeline_bytes = Vec::new();
    std::io::Read::read_to_end(&mut timeline_entry, &mut timeline_bytes)
        .expect("read timeline entry");
    let timeline: Value = serde_json::from_slice(&timeline_bytes).expect("timeline json");
    assert_eq!(
        timeline["export_type"].as_str(),
        Some("storyboard_timeline")
    );
    assert_eq!(timeline["shot_count"].as_i64(), Some(1));
    assert_eq!(timeline["total_duration_ms"].as_i64(), Some(5000));
    assert_eq!(
        timeline["shots"][0]["start_ms"].as_i64(),
        Some(0),
        "timeline should start at zero"
    );
    assert_eq!(timeline["shots"][0]["end_ms"].as_i64(), Some(5000));
    assert_eq!(timeline["shots"][0]["duration_seconds"].as_i64(), Some(5));
    assert_eq!(
        timeline["shots"][0]["subtitle_text"].as_str(),
        Some("旁白：主角抬头看向远方")
    );
    assert_eq!(
        timeline["shots"][0]["subtitle_source"].as_str(),
        Some("explicit_narration")
    );
    assert_eq!(
        timeline["shots"][0]["voiceover_ready"].as_bool(),
        Some(true)
    );
    drop(timeline_entry);
    let mut subtitles_entry = archive.by_name("subtitles.srt").expect("zip subtitles srt");
    let mut subtitles = String::new();
    std::io::Read::read_to_string(&mut subtitles_entry, &mut subtitles)
        .expect("read subtitles entry");
    assert!(subtitles.contains("1\n00:00:00,000 --> 00:00:05,000"));
    assert!(subtitles.contains("旁白：主角抬头看向远方"));
    drop(subtitles_entry);
    let mut voiceover_entry = archive
        .by_name("voiceover_script.txt")
        .expect("zip voiceover script");
    let mut voiceover_script = String::new();
    std::io::Read::read_to_string(&mut voiceover_entry, &mut voiceover_script)
        .expect("read voiceover entry");
    assert!(voiceover_script.contains("# Toonflow Storyboard Voiceover Script"));
    assert!(voiceover_script.contains("[00:00:00,000 - 00:00:05,000] Shot"));
    assert!(voiceover_script.contains("source=explicit_narration · voiceover_ready=true"));
    assert!(voiceover_script.contains("旁白：主角抬头看向远方"));
    drop(voiceover_entry);
    let mut voiceover_segments_entry = archive
        .by_name("voiceover_segments.json")
        .expect("zip voiceover segments");
    let mut voiceover_segments_bytes = Vec::new();
    std::io::Read::read_to_end(&mut voiceover_segments_entry, &mut voiceover_segments_bytes)
        .expect("read voiceover segments entry");
    let voiceover_segments: Value =
        serde_json::from_slice(&voiceover_segments_bytes).expect("voiceover segments json");
    assert_eq!(
        voiceover_segments["export_type"].as_str(),
        Some("storyboard_voiceover_segments")
    );
    assert_eq!(voiceover_segments["ready_count"].as_i64(), Some(1));
    assert_eq!(voiceover_segments["placeholder_count"].as_i64(), Some(0));
    assert_eq!(
        voiceover_segments["shots"][0]["subtitle_source"].as_str(),
        Some("explicit_narration")
    );
    assert_eq!(
        voiceover_segments["shots"][0]["voiceover_ready"].as_bool(),
        Some(true)
    );
    assert_eq!(
        voiceover_segments["shots"][0]["text"].as_str(),
        Some("旁白：主角抬头看向远方")
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
          AND p.numeric_id = $2
          AND s.numeric_id = $3
          AND vt.numeric_id = $4
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
          AND p.numeric_id = $2
          AND s.numeric_id = $3
          AND vt.numeric_id = $4
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
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"ids":[{storyboard_id}]}}"#
                )))
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
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"ids":[{storyboard_id}]}}"#
                )))
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

    let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}
