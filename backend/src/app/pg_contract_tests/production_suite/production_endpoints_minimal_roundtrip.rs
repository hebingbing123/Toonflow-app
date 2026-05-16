use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
async fn production_endpoints_minimal_roundtrip() {
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
    let project_id = created["numeric_id"].as_i64().expect("numeric_id") as i32;
    let project_uuid = created["id"].as_str().expect("project uuid");

    // Create script
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/scripts"))
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
    let script_id = script["numeric_id"].as_i64().expect("script numeric_id") as i32;

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
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"ids":[]}}"#
                )))
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
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"ids":[]}}"#
                )))
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
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"shotId":[]}}"#
                )))
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

    // Test edit-image/upload-image (workbench parity): validates ownership + returns normalized data URI
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
    let _ = sqlx::query("DELETE FROM public.app_script WHERE project_id IN (SELECT id FROM public.app_project WHERE numeric_id = $1)")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}
