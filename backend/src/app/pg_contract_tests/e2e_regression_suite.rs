//! End-to-End Regression Test Suite for Staging Environment
//!
//! This test suite validates the complete workflow from project creation to publish
//! in a staging environment. It covers:
//! - Project creation and configuration
//! - Script creation and storyboard generation
//! - Video generation workflow
//! - Quality gate validation
//! - Draft creation and publish job queueing
//! - Performance monitoring
//!
//! Tests are idempotent and include cleanup logic.

use super::*;
use serde_json::json;
use tower::ServiceExt;

/// Test data for end-to-end regression.
#[allow(dead_code)]
struct E2ETestContext {
    pool: PgPool,
    app: axum::Router,
    token: String,
    project_id: i32,
    project_uuid: String,
    script_id: i32,
    script_uuid: String,
    asset_ids: Vec<i32>,
    storyboard_ids: Vec<i32>,
    draft_ids: Vec<Uuid>,
    job_ids: Vec<Uuid>,
    quality_review_ids: Vec<Uuid>,
}

impl E2ETestContext {
    async fn cleanup(&self) {
        // Cleanup in reverse dependency order
        cleanup_jobs(&self.pool, &self.job_ids).await;
        cleanup_quality_reviews(&self.pool, &self.quality_review_ids).await;
        cleanup_llm_usage_rows_for_jobs(&self.pool, &self.job_ids).await;

        // Cleanup drafts
        for draft_id in &self.draft_ids {
            let _ = sqlx::query("DELETE FROM public.app_publish_draft WHERE id = $1")
                .bind(draft_id)
                .execute(&self.pool)
                .await;
        }

        // Cleanup storyboards
        for storyboard_id in &self.storyboard_ids {
            let _ = sqlx::query("DELETE FROM public.app_storyboard WHERE numeric_id = $1")
                .bind(storyboard_id)
                .execute(&self.pool)
                .await;
        }

        // Cleanup assets
        for asset_id in &self.asset_ids {
            let _ = sqlx::query("DELETE FROM public.app_asset WHERE numeric_id = $1")
                .bind(asset_id)
                .execute(&self.pool)
                .await;
        }

        // Cleanup script
        let _ = sqlx::query("DELETE FROM public.app_script WHERE numeric_id = $1")
            .bind(self.script_id)
            .execute(&self.pool)
            .await;

        // Cleanup project
        let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
            .bind(self.project_id)
            .execute(&self.pool)
            .await;
    }
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test e2e_regression -- --ignored"]
async fn test_e2e_project_creation_to_publish_workflow() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");
    ensure_contract_auth_user(&pool).await;

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let mut ctx = E2ETestContext {
        pool: pool.clone(),
        app: app.clone(),
        token: token.clone(),
        project_id: 0,
        project_uuid: String::new(),
        script_id: 0,
        script_uuid: String::new(),
        asset_ids: Vec::new(),
        storyboard_ids: Vec::new(),
        draft_ids: Vec::new(),
        job_ids: Vec::new(),
        quality_review_ids: Vec::new(),
    };

    // Step 1: Create project
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "name": "E2E Test Project",
                        "intro": "End-to-end regression test project"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    if status != StatusCode::CREATED {
        panic!("project created failed: status={status}, body={created}");
    }
    ctx.project_id = created["numeric_id"].as_i64().expect("numeric_id") as i32;
    ctx.project_uuid = created["id"].as_str().expect("project uuid").to_string();

    // Step 2: Create script
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{}/scripts", ctx.project_uuid))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "name": "E2E Test Script"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, script) = read_json_response(res).await;
    if status != StatusCode::CREATED {
        panic!("script created failed: status={status}, body={script}");
    }
    ctx.script_id = script["numeric_id"].as_i64().expect("script numeric_id") as i32;
    ctx.script_uuid = script["id"].as_str().expect("script uuid").to_string();

    // Step 3: Create track for storyboard/video workflow
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/workbench/add-track")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "projectId": ctx.project_id,
                        "scriptId": ctx.script_id,
                        "trackName": "Publish Workflow Track"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, track) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "track created");
    let track_id = track["trackId"].as_i64().expect("track id") as i32;

    // Step 4: Create storyboard
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{}/scripts/{}/storyboards",
                    ctx.project_uuid, ctx.script_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "prompt": "Test storyboard scene",
                        "duration": "5",
                        "track_id": track_id,
                        "flow_id": 1,
                        "sb_index": 0
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, storyboard) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "storyboard created");
    let storyboard_id = storyboard["numeric_id"]
        .as_i64()
        .expect("storyboard numeric_id") as i32;
    ctx.storyboard_ids.push(storyboard_id);

    // Step 5: Test quality gate validation
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/quality/reviews")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "projectId": ctx.project_id,
                        "scriptId": ctx.script_id,
                        "targetType": "script",
                        "targetId": format!("publish-flow-{}", ctx.script_id),
                        "overallScore": 9,
                        "passed": true,
                        "grade": "A",
                        "comments": "E2E test quality review"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, review) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "quality review created");
    let review_id = Uuid::parse_str(review["id"].as_str().expect("review id")).unwrap();
    ctx.quality_review_ids.push(review_id);

    // Step 6: Create draft for publishing
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{}/publish/drafts",
                    ctx.project_uuid
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "script_id": ctx.script_uuid,
                        "title": "E2E Test Draft",
                        "description": "Test draft for e2e regression",
                        "draft_status": "editing"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, draft) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "draft created");
    let draft_id = Uuid::parse_str(draft["id"].as_str().expect("draft id")).unwrap();
    ctx.draft_ids.push(draft_id);

    // Step 7: Queue publish job
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{}/publish/drafts/{}/jobs",
                    ctx.project_uuid, draft_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "payload": {
                            "platforms": ["douyin"],
                            "deliveryMode": "sandbox"
                        }
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "publish job created");
    let job_id = Uuid::parse_str(job["id"].as_str().expect("job id")).unwrap();
    ctx.job_ids.push(job_id);

    // Step 8: Verify data consistency
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/projects/{}", ctx.project_uuid))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, project_data) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "project data retrieved");
    let fetched_project_id = project_data["project"]["numeric_id"]
        .as_i64()
        .unwrap_or_else(|| panic!("unexpected project payload: {project_data}"))
        as i32;
    assert_eq!(fetched_project_id, ctx.project_id);

    // Cleanup
    ctx.cleanup().await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test e2e_regression -- --ignored"]
async fn test_e2e_video_generation_workflow() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");
    ensure_contract_auth_user(&pool).await;

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let mut ctx = E2ETestContext {
        pool: pool.clone(),
        app: app.clone(),
        token: token.clone(),
        project_id: 0,
        project_uuid: String::new(),
        script_id: 0,
        script_uuid: String::new(),
        asset_ids: Vec::new(),
        storyboard_ids: Vec::new(),
        draft_ids: Vec::new(),
        job_ids: Vec::new(),
        quality_review_ids: Vec::new(),
    };

    // Setup: Create project and script
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(json!({"name": "Video Gen Test"}).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    if status != StatusCode::CREATED {
        panic!("project create failed: status={status}, body={created}");
    }
    ctx.project_id = created["numeric_id"].as_i64().unwrap() as i32;
    ctx.project_uuid = created["id"].as_str().unwrap().to_string();

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{}/scripts", ctx.project_uuid))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(json!({"name": "Test Script"}).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, script) = read_json_response(res).await;
    if status != StatusCode::CREATED {
        panic!("script create failed: status={status}, body={script}");
    }
    ctx.script_id = script["numeric_id"].as_i64().unwrap() as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/workbench/add-track")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "projectId": ctx.project_id,
                        "scriptId": ctx.script_id,
                        "trackName": "Primary Track"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, track) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "track created");
    let track_id = track["trackId"].as_i64().unwrap() as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{}/scripts/{}/storyboards",
                    ctx.project_uuid, ctx.script_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "prompt": "Video workflow storyboard",
                        "duration": "5",
                        "track_id": track_id,
                        "flow_id": 1,
                        "sb_index": 0
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, storyboard) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "storyboard created");
    let storyboard_id = storyboard["numeric_id"].as_i64().unwrap() as i32;
    ctx.storyboard_ids.push(storyboard_id);

    // Test video generation endpoint
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/workbench/generate-video")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "projectId": ctx.project_id,
                        "scriptId": ctx.script_id,
                        "uploadData": [{
                            "id": storyboard_id,
                            "sources": "https://example.com/storyboard-frame.png",
                            "prompt": "Video workflow storyboard"
                        }],
                        "prompt": "test video generation",
                        "model": "test_model",
                        "mode": "test_mode",
                        "resolution": "720p",
                        "duration": 5,
                        "trackId": track_id
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "video generation initiated");

    // Test video list retrieval
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/workbench/get-video-list")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(json!({"projectId": ctx.project_id}).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "video list retrieved");
    assert!(body["total"].as_i64().is_some());

    // Cleanup
    ctx.cleanup().await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test e2e_regression -- --ignored"]
async fn test_e2e_quality_gate_enforcement() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");
    ensure_contract_auth_user(&pool).await;

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let mut ctx = E2ETestContext {
        pool: pool.clone(),
        app: app.clone(),
        token: token.clone(),
        project_id: 0,
        project_uuid: String::new(),
        script_id: 0,
        script_uuid: String::new(),
        asset_ids: Vec::new(),
        storyboard_ids: Vec::new(),
        draft_ids: Vec::new(),
        job_ids: Vec::new(),
        quality_review_ids: Vec::new(),
    };

    // Setup: Create project
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(json!({"name": "Quality Gate Test"}).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED);
    ctx.project_id = created["numeric_id"].as_i64().unwrap() as i32;
    ctx.project_uuid = created["id"].as_str().unwrap().to_string();

    // Test quality review creation with different pass/fail outcomes
    for (suffix, score, passed, is_bad_case) in [
        ("excellent", 9, true, false),
        ("good", 7, true, false),
        ("needs-work", 5, false, false),
        ("bad-case", 3, false, true),
    ] {
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/quality/reviews")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        json!({
                            "projectId": ctx.project_id,
                            "targetType": "script",
                            "targetId": format!("quality-gate-{suffix}"),
                            "overallScore": score,
                            "passed": passed,
                            "isBadCase": is_bad_case,
                            "comments": format!("Test review {suffix}")
                        })
                        .to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, review) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "quality review created");
        let review_id = Uuid::parse_str(review["id"].as_str().unwrap()).unwrap();
        ctx.quality_review_ids.push(review_id);
    }

    // Test quality review listing
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/quality/reviews?targetType=script")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, reviews) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "quality reviews retrieved");
    let reviews = reviews.as_array().expect("reviews list");
    assert!(
        reviews.len() >= 4,
        "expected at least the four created reviews, got {reviews:?}"
    );

    // Cleanup
    ctx.cleanup().await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test e2e_regression -- --ignored"]
async fn test_e2e_performance_monitoring() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let _token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    // Test metrics endpoint
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/metrics")
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let status = res.status();
    assert_eq!(status, StatusCode::OK, "metrics endpoint accessible");

    // Test health check
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/health")
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let status = res.status();
    assert_eq!(status, StatusCode::OK, "health check passed");
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test e2e_regression -- --ignored"]
async fn test_e2e_data_consistency_across_stages() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");
    ensure_contract_auth_user(&pool).await;

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let mut ctx = E2ETestContext {
        pool: pool.clone(),
        app: app.clone(),
        token: token.clone(),
        project_id: 0,
        project_uuid: String::new(),
        script_id: 0,
        script_uuid: String::new(),
        asset_ids: Vec::new(),
        storyboard_ids: Vec::new(),
        draft_ids: Vec::new(),
        job_ids: Vec::new(),
        quality_review_ids: Vec::new(),
    };

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
                .body(Body::from(
                    json!({"name": "Consistency Test", "intro": "Test data consistency"})
                        .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED);
    ctx.project_id = created["numeric_id"].as_i64().unwrap() as i32;
    ctx.project_uuid = created["id"].as_str().unwrap().to_string();

    // Verify project data immediately after creation
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/projects/{}", ctx.project_uuid))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, project_data) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        project_data["project"]["name"].as_str().unwrap(),
        "Consistency Test"
    );
    assert_eq!(
        project_data["project"]["intro"].as_str().unwrap(),
        "Test data consistency"
    );

    // Update project
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/projects/{}", ctx.project_uuid))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({"name": "Updated Consistency Test"}).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK);

    // Verify update persisted
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/projects/{}", ctx.project_uuid))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, project_data) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        project_data["project"]["name"].as_str().unwrap(),
        "Updated Consistency Test"
    );

    // Cleanup
    ctx.cleanup().await;
}
