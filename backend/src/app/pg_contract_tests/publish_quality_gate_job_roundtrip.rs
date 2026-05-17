//! Publish job quality gate by project `quality_gate_strategy` (需求 I.2).

use super::*;
use serde_json::json;
use tower::ServiceExt;

const JOB_PAYLOAD: &str = r#"{"payload":{"platforms":["douyin"],"deliveryMode":"sandbox"}}"#;

async fn cleanup_publish_fixtures(
    pool: &PgPool,
    publish_job_ids: &[Uuid],
    draft_ids: &[Uuid],
    script_numeric_id: i32,
    project_numeric_id: i32,
) {
    if !publish_job_ids.is_empty() {
        let _ = sqlx::query("DELETE FROM public.app_publish_job WHERE id = ANY($1)")
            .bind(publish_job_ids)
            .execute(pool)
            .await;
    }
    for draft_id in draft_ids {
        let _ = sqlx::query("DELETE FROM public.app_publish_draft WHERE id = $1")
            .bind(draft_id)
            .execute(pool)
            .await;
    }
    let _ = sqlx::query("DELETE FROM public.app_script WHERE numeric_id = $1")
        .bind(script_numeric_id)
        .execute(pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
        .bind(project_numeric_id)
        .execute(pool)
        .await;
}

async fn patch_project_strategy(
    app: &axum::Router,
    token: &str,
    project_uuid: &str,
    strategy: &str,
) {
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"qualityGateStrategy":"{strategy}"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patch strategy={strategy}: {body}");
}

async fn create_script(app: &axum::Router, token: &str, project_uuid: &str) -> (i32, String) {
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/scripts"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({ "name": format!("pg_pub_qg_{}", Uuid::new_v4()) }).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, script) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "script: {script}");
    let numeric_id = script["numeric_id"].as_i64().expect("numeric_id") as i32;
    let uuid = script["id"].as_str().expect("script uuid").to_string();
    (numeric_id, uuid)
}

async fn create_draft(
    app: &axum::Router,
    token: &str,
    project_uuid: &str,
    script_uuid: Option<&str>,
    title_suffix: &str,
) -> Uuid {
    let mut body = json!({
        "title": format!("pg pub qg {title_suffix}"),
        "description": "quality gate contract",
        "draft_status": "editing"
    });
    if let Some(script_id) = script_uuid {
        body["script_id"] = json!(script_id);
    }
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/publish/drafts"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, draft) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "draft: {draft}");
    Uuid::parse_str(draft["id"].as_str().expect("draft id")).unwrap()
}

async fn queue_publish_job(
    app: &axum::Router,
    token: &str,
    project_uuid: &str,
    draft_id: Uuid,
) -> (StatusCode, serde_json::Value) {
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/publish/drafts/{draft_id}/jobs"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(JOB_PAYLOAD))
                .unwrap(),
        )
        .await
        .unwrap();
    read_json_response(res).await
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET; cargo test publish_quality_gate_job_contract -- --ignored"]
async fn publish_quality_gate_job_contract() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");
    ensure_contract_auth_user(&pool).await;

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
                .body(Body::from(format!(
                    r#"{{"name":"pg_pub_qg_{}","qualityGateStrategy":"block"}}"#,
                    Uuid::new_v4().simple()
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, project) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "project: {project}");
    let project_uuid = project["id"].as_str().expect("project uuid").to_string();
    let project_numeric_id = project["numeric_id"].as_i64().expect("numeric_id") as i32;

    let (script_numeric_id, script_uuid) = create_script(&app, &token, &project_uuid).await;

    let draft_with_script = create_draft(
        &app,
        &token,
        &project_uuid,
        Some(&script_uuid),
        "with_script",
    )
    .await;
    let (status, blocked) = queue_publish_job(&app, &token, &project_uuid, draft_with_script).await;
    assert_eq!(
        status,
        StatusCode::CONFLICT,
        "block strategy + missing roles/storyboards should 409: {blocked}"
    );
    let message = blocked["message"]
        .as_str()
        .or_else(|| blocked["error"].as_str())
        .unwrap_or("");
    assert!(
        message.contains("video_generate")
            || serde_json::to_string(&blocked)
                .unwrap()
                .contains("video_generate"),
        "expected stage in error body: {blocked}"
    );

    patch_project_strategy(&app, &token, &project_uuid, "off").await;
    let draft_off = create_draft(&app, &token, &project_uuid, Some(&script_uuid), "off").await;
    let (status, job_off) = queue_publish_job(&app, &token, &project_uuid, draft_off).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "off strategy should queue job: {job_off}"
    );
    let job_off_id = Uuid::parse_str(job_off["id"].as_str().expect("job id")).unwrap();

    patch_project_strategy(&app, &token, &project_uuid, "warn").await;
    let draft_warn = create_draft(&app, &token, &project_uuid, Some(&script_uuid), "warn").await;
    let (status, job_warn) = queue_publish_job(&app, &token, &project_uuid, draft_warn).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "warn strategy should queue despite severe issues: {job_warn}"
    );
    let job_warn_id = Uuid::parse_str(job_warn["id"].as_str().expect("job id")).unwrap();

    patch_project_strategy(&app, &token, &project_uuid, "block").await;
    let draft_no_script = create_draft(&app, &token, &project_uuid, None, "no_script").await;
    let (status, job_no_script) =
        queue_publish_job(&app, &token, &project_uuid, draft_no_script).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "draft without script_id skips quality gate: {job_no_script}"
    );
    let job_no_script_id = Uuid::parse_str(job_no_script["id"].as_str().expect("job id")).unwrap();

    cleanup_publish_fixtures(
        &pool,
        &[job_off_id, job_warn_id, job_no_script_id],
        &[draft_with_script, draft_off, draft_warn, draft_no_script],
        script_numeric_id,
        project_numeric_id,
    )
    .await;
}
