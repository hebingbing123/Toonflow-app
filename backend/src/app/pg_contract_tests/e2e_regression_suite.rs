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

/// Test data for end-to-end regression
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
                        "title": "E2E Test Project",
                        "description": "End-to-end regression test project"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "project created");
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
                        "title": "E2E Test Script",
                        "content": "Test script content"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, script) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "script created");
    ctx.script_id = script["numeric_id"].as_i64().expect("script numeric_id") as i32;
    ctx.script_uuid = script["id"].as_str().expect("script uuid").to_string();

    // Step 3: Create test assets
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "projectId": ctx.project_id,
                        "name": "Test Character",
                        "type": "character",
                        "prompt": "A test character for e2e testing"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, asset) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "asset created");
    let asset_id = asset["numeric_id"].as_i64().expect("asset numeric_id") as i32;
    ctx.asset_ids.push(asset_id);

    // Step 4: Create storyboard
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/storyboard")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "projectId": ctx.project_id,
                        "scriptId": ctx.script_id,
                        "videoDesc": "Test storyboard scene",
                        "duration": 5,
                        "track": 1
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
                .uri("/api/v1/quality-reviews")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "projectId": ctx.project_id,
                        "stage": "storyboard",
                        "grade": "A",
                        "notes": "E2E test quality review"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, review) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "quality review created");
    let review_id = Uuid::parse_str(review["id"].as_str().expect("review id")).unwrap();
    ctx.quality_review_ids.push(review_id);

    // Step 6: Create draft for publishing
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/publish/drafts")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "projectId": ctx.project_id,
                        "scriptId": ctx.script_id,
                        "title": "E2E Test Draft",
                        "description": "Test draft for e2e regression"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, draft) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "draft created");
    let draft_id = Uuid::parse_str(draft["id"].as_str().expect("draft id")).unwrap();
    ctx.draft_ids.push(draft_id);

    // Step 7: Queue publish job
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/publish/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "draftId": draft_id.to_string(),
                        "platforms": ["douyin"],
                        "deliveryMode": "sandbox"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "publish job created");
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
    assert_eq!(
        project_data["numeric_id"].as_i64().unwrap() as i32,
        ctx.project_id
    );

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
                .body(Body::from(json!({"title": "Video Gen Test"}).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED);
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
                .body(Body::from(json!({"title": "Test Script"}).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, script) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED);
    ctx.script_id = script["numeric_id"].as_i64().unwrap() as i32;

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
                        "uploadData": [],
                        "prompt": "test video generation",
                        "model": "test_model",
                        "mode": "test_mode",
                        "resolution": "720p",
                        "duration": 5,
                        "trackId": 1
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
                .body(Body::from("{}"))
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
                .body(Body::from(
                    json!({"title": "Quality Gate Test"}).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED);
    ctx.project_id = created["numeric_id"].as_i64().unwrap() as i32;

    // Test quality review creation with different grades
    for grade in &["A", "B", "C", "D"] {
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/quality-reviews")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(
                        json!({
                            "projectId": ctx.project_id,
                            "stage": "storyboard",
                            "grade": grade,
                            "notes": format!("Test grade {}", grade)
                        })
                        .to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, review) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "quality review created");
        let review_id = Uuid::parse_str(review["id"].as_str().unwrap()).unwrap();
        ctx.quality_review_ids.push(review_id);
    }

    // Test quality review stats
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/quality-reviews/stats")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, stats) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "quality stats retrieved");
    assert!(stats.is_object());

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
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    // Test metrics endpoint
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/metrics")
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
                    json!({"title": "Consistency Test", "description": "Test data consistency"})
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
    assert_eq!(project_data["title"].as_str().unwrap(), "Consistency Test");
    assert_eq!(
        project_data["description"].as_str().unwrap(),
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
                    json!({"title": "Updated Consistency Test"}).to_string(),
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
        project_data["title"].as_str().unwrap(),
        "Updated Consistency Test"
    );

    // Cleanup
    ctx.cleanup().await;
}
