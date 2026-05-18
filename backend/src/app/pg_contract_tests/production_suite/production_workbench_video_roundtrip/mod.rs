use serde_json::Value;
use std::io::Cursor;
use zip::ZipArchive;

mod helpers;

use crate::app::pg_contract_tests::{header, read_bytes_response, StatusCode};

use helpers::{
    connect_contract_app, count_agent_memory_rows, count_video_track_rows, create_project,
    create_script, create_storyboard, get_flow_data, get_production_data, post_json_response,
    read_storyboard_indexes, read_zip_string_entry, save_flow_data, save_storyboard_image_url,
    save_workbench_video_action,
};

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn production_workbench_video_roundtrip() {
    let (pool, token, app, sub) = connect_contract_app().await;

    let (project_id, project_uuid) = create_project(&app, &token).await;
    let script_id = create_script(&app, &token, &project_uuid, "pg_video_script").await;
    let storyboard_id = create_storyboard(
        &app,
        &token,
        &project_uuid,
        script_id,
        r#"{"prompt":"pg_video_storyboard","duration":"5","track_id":7,"flow_id":21,"sb_index":1}"#,
    )
    .await;
    let storyboard_two_id = create_storyboard(
        &app,
        &token,
        &project_uuid,
        script_id,
        r#"{"prompt":"pg_video_storyboard_two","duration":"6","track_id":9,"flow_id":22,"sb_index":2}"#,
    )
    .await;

    let production_data =
        get_production_data(&app, &token, project_id, script_id, &[storyboard_id]).await;
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

    let initial_flow_data = get_flow_data(&app, &token, project_id, script_id).await;
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

    save_flow_data(
        &app,
        &token,
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
        }),
    )
    .await;

    let saved_flow_data = get_flow_data(&app, &token, project_id, script_id).await;
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
    let reordered_indexes =
        read_storyboard_indexes(&pool, &[storyboard_id, storyboard_two_id]).await;
    assert_eq!(
        reordered_indexes,
        vec![(storyboard_id, Some(1)), (storyboard_two_id, Some(0))]
    );

    let storyboard_data_uri =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a8Z8AAAAASUVORK5CYII=";
    let updated_storyboard = save_storyboard_image_url(
        &app,
        &token,
        project_id,
        script_id,
        storyboard_id,
        storyboard_data_uri,
    )
    .await;
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

    let polling_image = post_json_response(
        &app,
        &token,
        "/api/v1/production/storyboard/polling-image",
        serde_json::json!({
            "projectId": project_id,
            "scriptId": script_id,
            "ids": [storyboard_id],
        }),
    )
    .await;
    assert_eq!(
        polling_image.0,
        StatusCode::OK,
        "polling-image should accept owned storyboard"
    );

    let export_image_res = helpers::post_json_raw_response(
        &app,
        &token,
        "/api/v1/production/export-image",
        serde_json::json!({
            "projectId": project_id,
            "scriptId": script_id,
            "shotId": [{"id": storyboard_id.to_string()}],
        }),
    )
    .await;
    let content_disposition = export_image_res
        .headers()
        .get(header::CONTENT_DISPOSITION)
        .and_then(|v| v.to_str().ok())
        .map(str::to_string);
    let (status, body, ct) = read_bytes_response(export_image_res, 512 * 1024).await;
    assert_eq!(status, StatusCode::OK, "export-image should return zip");
    assert_eq!(ct.as_deref(), Some("application/zip"));
    assert!(
        content_disposition
            .as_deref()
            .unwrap_or_default()
            .contains("openflow-storyboards-"),
        "content-disposition={content_disposition:?}"
    );

    let cursor = Cursor::new(body);
    let mut archive = ZipArchive::new(cursor).expect("valid zip");
    assert_eq!(
        archive.len(),
        8,
        "image + manifest + csv + timeline + subtitles + voiceover script + voiceover segments + assembly plan expected in zip"
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

    let manifest_bytes = read_zip_string_entry(&mut archive, "manifest.json");
    let manifest: Value = serde_json::from_str(&manifest_bytes).expect("manifest json");
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

    let csv = read_zip_string_entry(&mut archive, "storyboard.csv");
    assert!(csv.starts_with(
        "storyboard_id,order_index,storyboard_index,track_id,duration,state,prompt,subtitle_source,voiceover_ready,image_filename,image_source\n"
    ));
    assert!(csv.contains(&storyboard_id.to_string()));
    assert!(csv.contains("explicit_narration,true"));

    let timeline_bytes = read_zip_string_entry(&mut archive, "timeline.json");
    let timeline: Value = serde_json::from_str(&timeline_bytes).expect("timeline json");
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

    let subtitles = read_zip_string_entry(&mut archive, "subtitles.srt");
    assert!(subtitles.contains("1\n00:00:00,000 --> 00:00:05,000"));
    assert!(subtitles.contains("旁白：主角抬头看向远方"));

    let voiceover_script = read_zip_string_entry(&mut archive, "voiceover_script.txt");
    assert!(voiceover_script.contains("# Toonflow Storyboard Voiceover Script"));
    assert!(voiceover_script.contains("[00:00:00,000 - 00:00:05,000] Shot"));
    assert!(voiceover_script.contains("source=explicit_narration · voiceover_ready=true"));
    assert!(voiceover_script.contains("旁白：主角抬头看向远方"));

    let voiceover_segments_bytes = read_zip_string_entry(&mut archive, "voiceover_segments.json");
    let voiceover_segments: Value =
        serde_json::from_str(&voiceover_segments_bytes).expect("voiceover segments json");
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

    let assembly_plan_bytes = read_zip_string_entry(&mut archive, "assembly_plan.json");
    let assembly_plan: Value =
        serde_json::from_str(&assembly_plan_bytes).expect("assembly plan json");
    assert_eq!(
        assembly_plan["export_type"].as_str(),
        Some("storyboard_assembly_plan")
    );
    assert_eq!(assembly_plan["audio_ready_count"].as_i64(), Some(1));
    assert_eq!(assembly_plan["placeholder_audio_count"].as_i64(), Some(0));
    assert_eq!(
        assembly_plan["shots"][0]["image_filename"].as_str(),
        Some(format!("storyboard-{storyboard_id}.png").as_str())
    );
    assert_eq!(
        assembly_plan["shots"][0]["subtitle_source"].as_str(),
        Some("explicit_narration")
    );
    assert_eq!(
        assembly_plan["shots"][0]["voiceover_ready"].as_bool(),
        Some(true)
    );
    assert_eq!(
        assembly_plan["shots"][0]["suggested_transition"].as_str(),
        Some("cut")
    );

    let add_track = save_workbench_video_action(
        &app,
        &token,
        "/api/v1/production/workbench/add-track",
        serde_json::json!({
            "projectId": project_id,
            "scriptId": script_id,
            "trackName": "B-roll",
        }),
    )
    .await;
    assert_eq!(
        add_track["track_id"].as_i64(),
        Some(8),
        "add-track should allocate next track id"
    );
    let persisted_track_count =
        count_video_track_rows(&pool, sub, project_id, script_id, 8_i32).await;
    assert_eq!(
        persisted_track_count, 1,
        "add-track should persist app_video_track row"
    );

    let selected_video_url = "https://cdn.example.com/pg-contract-video.mp4";
    let selected = save_workbench_video_action(
        &app,
        &token,
        "/api/v1/production/workbench/select-video",
        serde_json::json!({
            "projectId": project_id,
            "scriptId": script_id,
            "storyboardId": storyboard_id,
            "videoUrl": selected_video_url,
        }),
    )
    .await;
    assert_eq!(selected["video_url"].as_str(), Some(selected_video_url));
    let selected_memory_count = count_agent_memory_rows(
        &pool,
        sub,
        project_id,
        script_id,
        "selected_video_memory",
        Some(format!("%storyboardIds={storyboard_id}%")),
    )
    .await;
    assert_eq!(
        selected_memory_count, 1,
        "select-video should persist storyboard-scoped selected video memory"
    );
    let script_style_memory_count = count_agent_memory_rows(
        &pool,
        sub,
        project_id,
        script_id,
        "script_video_style_memory",
        None,
    )
    .await;
    assert_eq!(
        script_style_memory_count, 0,
        "single approved video should not yet create script style summary"
    );

    let track_videos = save_workbench_video_action(
        &app,
        &token,
        "/api/v1/production/workbench/get-video-list",
        serde_json::json!({
            "projectId": project_id,
            "trackId": 7,
        }),
    )
    .await;
    assert_eq!(track_videos["total"].as_i64(), Some(1));
    assert_eq!(
        track_videos["videos"][0]["id"].as_i64(),
        Some(i64::from(storyboard_id))
    );
    assert_eq!(
        track_videos["videos"][0]["video_url"].as_str(),
        Some(selected_video_url)
    );

    let deleted_track = save_workbench_video_action(
        &app,
        &token,
        "/api/v1/production/workbench/delete-track",
        serde_json::json!({
            "projectId": project_id,
            "scriptId": script_id,
            "trackId": 7,
        }),
    )
    .await;
    assert_eq!(deleted_track["track_id"].as_i64(), Some(7));
    let deleted_track_count =
        count_video_track_rows(&pool, sub, project_id, script_id, 7_i32).await;
    assert_eq!(
        deleted_track_count, 0,
        "delete-track should remove persisted app_video_track row"
    );

    let cleared_track_data =
        get_production_data(&app, &token, project_id, script_id, &[storyboard_id]).await;
    assert!(
        cleared_track_data["data"][0]["trackId"].is_null(),
        "delete-track should clear storyboard track assignment"
    );
    assert_eq!(
        cleared_track_data["data"][0]["url"].as_str(),
        Some(selected_video_url),
        "delete-track must not remove selected video"
    );

    let filtered_after_delete_track = save_workbench_video_action(
        &app,
        &token,
        "/api/v1/production/workbench/get-video-list",
        serde_json::json!({
            "projectId": project_id,
            "trackId": 7,
        }),
    )
    .await;
    assert_eq!(filtered_after_delete_track["total"].as_i64(), Some(0));

    let all_videos_before_delete_video = save_workbench_video_action(
        &app,
        &token,
        "/api/v1/production/workbench/get-video-list",
        serde_json::json!({
            "projectId": project_id,
        }),
    )
    .await;
    assert_eq!(all_videos_before_delete_video["total"].as_i64(), Some(1));

    let deleted_video = save_workbench_video_action(
        &app,
        &token,
        "/api/v1/production/workbench/delete-video",
        serde_json::json!({
            "projectId": project_id,
            "scriptId": script_id,
            "storyboardId": storyboard_id,
        }),
    )
    .await;
    assert_eq!(
        deleted_video["storyboard_id"].as_i64(),
        Some(i64::from(storyboard_id))
    );

    let after_delete_video =
        get_production_data(&app, &token, project_id, script_id, &[storyboard_id]).await;
    assert!(after_delete_video["data"][0]["url"].is_null());
    assert!(after_delete_video["data"][0]["state"].is_null());
    let selected_memory_after_delete = count_agent_memory_rows(
        &pool,
        sub,
        project_id,
        script_id,
        "selected_video_memory",
        Some(format!("%storyboardIds={storyboard_id}%")),
    )
    .await;
    assert_eq!(
        selected_memory_after_delete, 0,
        "delete-video should clear stale selected video memory for the storyboard"
    );
    let script_style_memory_after_delete = count_agent_memory_rows(
        &pool,
        sub,
        project_id,
        script_id,
        "script_video_style_memory",
        None,
    )
    .await;
    assert_eq!(
        script_style_memory_after_delete, 0,
        "delete-video should also leave no script style memory when no approved videos remain"
    );

    let all_videos_after_delete_video = save_workbench_video_action(
        &app,
        &token,
        "/api/v1/production/workbench/get-video-list",
        serde_json::json!({
            "projectId": project_id,
        }),
    )
    .await;
    assert_eq!(all_videos_after_delete_video["total"].as_i64(), Some(0));

    let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn production_flow_version_conflict_detection() {
    let (pool, token, app, _sub) = connect_contract_app().await;

    let (project_id, project_uuid) = create_project(&app, &token).await;
    let script_id = create_script(&app, &token, &project_uuid, "pg_version_test").await;
    let storyboard_id = create_storyboard(
        &app,
        &token,
        &project_uuid,
        script_id,
        r#"{"prompt":"version_test_storyboard","duration":"5","track_id":1,"flow_id":1,"sb_index":0}"#,
    )
    .await;

    // Initial save to create flow record
    save_flow_data(
        &app,
        &token,
        serde_json::json!({
            "projectId": project_id,
            "episodesId": script_id,
            "data": {
                "scriptPlan": "initial-plan",
                "storyboard": [{"id": storyboard_id}],
            }
        }),
    )
    .await;

    // Get flow data with version
    let flow_data = get_flow_data(&app, &token, project_id, script_id).await;
    let version = flow_data["flowVersion"]
        .as_str()
        .expect("flowVersion should be present");
    assert!(!version.is_empty(), "flowVersion should not be empty");

    // Save with correct version should succeed
    save_flow_data(
        &app,
        &token,
        serde_json::json!({
            "projectId": project_id,
            "episodesId": script_id,
            "flowVersion": version,
            "data": {
                "scriptPlan": "updated-plan",
                "storyboard": [{"id": storyboard_id}],
            }
        }),
    )
    .await;

    // Verify the update succeeded
    let updated_flow = get_flow_data(&app, &token, project_id, script_id).await;
    assert_eq!(updated_flow["scriptPlan"].as_str(), Some("updated-plan"));
    let new_version = updated_flow["flowVersion"]
        .as_str()
        .expect("flowVersion should be present after update");
    assert_ne!(version, new_version, "version should change after update");

    // Save with stale version should fail with 409 Conflict
    let stale_save_res = helpers::post_json_raw_response(
        &app,
        &token,
        "/api/v1/production/save-flow-data",
        serde_json::json!({
            "projectId": project_id,
            "episodesId": script_id,
            "flowVersion": version, // Using old version
            "data": {
                "scriptPlan": "conflicting-plan",
                "storyboard": [{"id": storyboard_id}],
            }
        }),
    )
    .await;

    assert_eq!(
        stale_save_res.status(),
        StatusCode::CONFLICT,
        "save with stale version should return 409 Conflict"
    );

    let (_, body, _) = read_bytes_response(stale_save_res, 4096).await;
    let error_body: Value = serde_json::from_slice(&body).expect("error body json");
    assert_eq!(error_body["code"].as_str(), Some("conflict"));
    assert_eq!(error_body["status"], 409);
    assert!(
        error_body["message"]
            .as_str()
            .unwrap_or_default()
            .contains("Timeline has been modified"),
        "error message should explain version conflict"
    );
    // Verify details field contains version information
    assert!(
        error_body["details"].is_object(),
        "details should be present"
    );
    assert_eq!(
        error_body["details"]["expected_version"].as_str(),
        Some(version),
        "details should include expected version"
    );
    assert_eq!(
        error_body["details"]["current_version"].as_str(),
        Some(new_version),
        "details should include current version"
    );
    assert_eq!(
        error_body["details"]["conflict_type"].as_str(),
        Some("version_mismatch"),
        "details should include conflict type"
    );

    // Verify the conflicting save did not apply
    let final_flow = get_flow_data(&app, &token, project_id, script_id).await;
    assert_eq!(
        final_flow["scriptPlan"].as_str(),
        Some("updated-plan"),
        "conflicting save should not have applied"
    );

    // Save without version should still work (backward compatibility)
    save_flow_data(
        &app,
        &token,
        serde_json::json!({
            "projectId": project_id,
            "episodesId": script_id,
            "data": {
                "scriptPlan": "no-version-plan",
                "storyboard": [{"id": storyboard_id}],
            }
        }),
    )
    .await;

    let no_version_flow = get_flow_data(&app, &token, project_id, script_id).await;
    assert_eq!(
        no_version_flow["scriptPlan"].as_str(),
        Some("no-version-plan"),
        "save without version should work for backward compatibility"
    );

    let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}
