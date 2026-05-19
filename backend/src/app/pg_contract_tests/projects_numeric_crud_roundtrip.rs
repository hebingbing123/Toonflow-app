use super::*;

use serde_json::json;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn project_numeric_crud_roundtrip() {
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

    let unique_suffix = Uuid::new_v4().simple().to_string();
    let initial_name = format!("pg_numeric_project_{unique_suffix}");
    let updated_name = format!("{initial_name}_updated");

    let create_body = json!({
        "name": initial_name,
        "intro": "seed intro",
        "projectType": "short-drama",
        "textModel": "1:gpt-4.1-mini",
        "multimodalModel": "1:gpt-4o",
        "artStyle": "ink",
        "directorManual": "story-manual",
        "videoRatio": "9:16",
        "imageModel": "dalle-3",
        "videoModel": "runway",
        "voiceModel": "gpt-4o-mini-tts",
        "voiceProfile": "{\"voice\":\"alloy\"}",
        "imageQuality": "hd",
        "mode": "animated.short_drama",
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(create_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, added) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "added={added}");
    let project_uuid = added["id"].as_str().expect("project id").to_owned();
    let workspace_id = added["workspace_id"]
        .as_str()
        .expect("workspace id")
        .to_owned();
    let numeric_id = added["numeric_id"].as_i64().expect("numeric_id") as i32;

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
    let (status, listed) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "listed={listed}");
    let created_row = listed
        .as_array()
        .and_then(|rows| {
            rows.iter()
                .find(|row| row["name"].as_str() == Some(initial_name.as_str()))
        })
        .cloned()
        .expect("created project row");
    assert_eq!(
        created_row["numeric_id"].as_i64(),
        Some(i64::from(numeric_id))
    );
    assert_eq!(
        created_row["workspace_id"].as_str(),
        Some(workspace_id.as_str())
    );
    assert_eq!(created_row["intro"].as_str(), Some("seed intro"));
    assert_eq!(created_row["project_type"].as_str(), Some("short-drama"));
    assert_eq!(created_row["text_model"].as_str(), Some("1:gpt-4.1-mini"));
    assert_eq!(created_row["multimodal_model"].as_str(), Some("1:gpt-4o"));
    assert_eq!(created_row["mode"].as_str(), Some("animated.short_drama"));
    assert_eq!(created_row["art_style"].as_str(), Some("ink"));
    assert_eq!(
        created_row["director_manual"].as_str(),
        Some("story-manual")
    );
    assert_eq!(created_row["video_ratio"].as_str(), Some("9:16"));
    assert_eq!(created_row["image_model"].as_str(), Some("dalle-3"));
    assert_eq!(created_row["video_model"].as_str(), Some("runway"));
    assert_eq!(created_row["voice_model"].as_str(), Some("gpt-4o-mini-tts"));
    assert_eq!(
        created_row["voice_profile"].as_str(),
        Some("{\"voice\":\"alloy\"}")
    );
    assert_eq!(created_row["image_quality"].as_str(), Some("hd"));

    let stored_mode: Option<String> = sqlx::query_scalar(
        "SELECT mode FROM public.app_project WHERE owner_user_id = $1 AND numeric_id = $2",
    )
    .bind(sub)
    .bind(numeric_id)
    .fetch_optional(&pool)
    .await
    .expect("select initial mode");
    assert_eq!(stored_mode.as_deref(), Some("animated.short_drama"));

    let stored_workspace_id: Option<Uuid> = sqlx::query_scalar(
        "SELECT workspace_id FROM public.app_project WHERE owner_user_id = $1 AND numeric_id = $2",
    )
    .bind(sub)
    .bind(numeric_id)
    .fetch_optional(&pool)
    .await
    .expect("select workspace id")
    .flatten();
    assert_eq!(
        stored_workspace_id.as_ref().map(Uuid::to_string).as_deref(),
        Some(workspace_id.as_str())
    );

    let patch_body = json!({
        "name": updated_name,
        "intro": "updated intro",
        "projectType": "feature",
        "textModel": " 1:o4-mini ",
        "multimodalModel": " 1:gpt-4.1 ",
        "artStyle": "charcoal",
        "directorManual": "revised-manual",
        "videoRatio": "16:9",
        "imageModel": " flux ",
        "videoModel": " kling ",
        "voiceModel": " gpt-4.1-mini-tts ",
        "voiceProfile": " {\"voice\":\"nova\"} ",
        "imageQuality": "standard",
        "mode": "live_action.short_drama",
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(patch_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patched={_patched}");

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
    let (status, relisted) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "relisted={relisted}");
    let edited_row = relisted
        .as_array()
        .and_then(|rows| {
            rows.iter()
                .find(|row| row["numeric_id"].as_i64() == Some(i64::from(numeric_id)))
        })
        .cloned()
        .expect("edited project row");
    assert_eq!(edited_row["name"].as_str(), Some(updated_name.as_str()));
    assert_eq!(edited_row["intro"].as_str(), Some("updated intro"));
    assert_eq!(edited_row["project_type"].as_str(), Some("feature"));
    assert_eq!(edited_row["text_model"].as_str(), Some("1:o4-mini"));
    assert_eq!(edited_row["multimodal_model"].as_str(), Some("1:gpt-4.1"));
    assert_eq!(edited_row["mode"].as_str(), Some("live_action.short_drama"));
    assert_eq!(edited_row["art_style"].as_str(), Some("charcoal"));
    assert_eq!(
        edited_row["director_manual"].as_str(),
        Some("revised-manual")
    );
    assert_eq!(edited_row["video_ratio"].as_str(), Some("16:9"));
    assert_eq!(edited_row["image_model"].as_str(), Some("flux"));
    assert_eq!(edited_row["video_model"].as_str(), Some("kling"));
    assert_eq!(edited_row["voice_model"].as_str(), Some("gpt-4.1-mini-tts"));
    assert_eq!(
        edited_row["voice_profile"].as_str(),
        Some("{\"voice\":\"nova\"}")
    );
    assert_eq!(edited_row["image_quality"].as_str(), Some("standard"));

    let stored_mode: Option<String> = sqlx::query_scalar(
        "SELECT mode FROM public.app_project WHERE owner_user_id = $1 AND numeric_id = $2",
    )
    .bind(sub)
    .bind(numeric_id)
    .fetch_optional(&pool)
    .await
    .expect("select edited mode");
    assert_eq!(stored_mode.as_deref(), Some("live_action.short_drama"));

    let res = app
        .clone()
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
    let status = res.status();
    assert_eq!(status, StatusCode::NO_CONTENT, "delete status");

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
    let (status, after_delete) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "after_delete={after_delete}");
    let still_present = after_delete.as_array().is_some_and(|rows| {
        rows.iter()
            .any(|row| row["numeric_id"].as_i64() == Some(i64::from(numeric_id)))
    });
    assert!(
        !still_present,
        "deleted row should be absent: {after_delete}"
    );

    let res = app
        .clone()
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
    let (status, missing_delete) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "missing_delete={missing_delete}"
    );
}
