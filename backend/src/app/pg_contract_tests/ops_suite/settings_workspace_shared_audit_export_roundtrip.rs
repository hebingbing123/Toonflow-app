//! Workspace shared cleared-template audit **async** export (real Postgres + worker tick).

use super::super::*;
use crate::jobs::worker::contract_worker_process_one_tick;
use serde_json::json;
use tower::ServiceExt;

struct RemoveEnvVarGuard(&'static str);

impl Drop for RemoveEnvVarGuard {
    fn drop(&mut self) {
        std::env::remove_var(self.0);
    }
}

async fn create_workspace_and_switch_current(app: &axum::Router, token: &str) -> Uuid {
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/workspaces")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"name":"PG WS Shared Audit Export"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "create workspace: {created}");
    let workspace_id =
        Uuid::parse_str(created["id"].as_str().expect("workspace id")).expect("parse workspace id");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri("/api/v1/me/current-workspace")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"workspace_id":"{workspace_id}"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, switched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "switch workspace: {switched}");
    workspace_id
}

async fn delete_workspace_fixtures(pool: &PgPool, workspace_id: Uuid) {
    let _ = sqlx::query("DELETE FROM public.app_workspace_member WHERE workspace_id = $1")
        .bind(workspace_id)
        .execute(pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
        .bind(workspace_id)
        .execute(pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; supabase db reset; cargo test settings_workspace_shared_audit_export_async_worker_roundtrip -- --ignored"]
async fn settings_workspace_shared_audit_export_async_worker_roundtrip() {
    let _ = dotenvy::dotenv();
    let dir = tempfile::tempdir().expect("tempdir");
    std::env::set_var(
        "TOONFLOW_LOCAL_WORKSPACE_SHARED_AUDIT_EXPORT_DIR",
        dir.path().to_string_lossy().as_ref(),
    );
    let _env_guard = RemoveEnvVarGuard("TOONFLOW_LOCAL_WORKSPACE_SHARED_AUDIT_EXPORT_DIR");

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
    let state = contract_state(pool.clone(), secret);
    let app = build_router(state.clone());

    let workspace_id = create_workspace_and_switch_current(&app, &token).await;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-async")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"format":"json"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, enq) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "enqueue export-async: {enq}");
    let job_id = enq["id"].as_str().expect("job id").to_string();
    let job_uuid = Uuid::parse_str(&job_id).expect("parse job uuid");

    let mut finished = false;
    for _ in 0..40 {
        contract_worker_process_one_tick(&state, &pool)
            .await
            .expect("worker tick");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-jobs/{job_id}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (st, job) = read_json_response(res).await;
        assert_eq!(st, StatusCode::OK, "poll job: {job}");
        if job["downloadReady"] == json!(true) {
            finished = true;
            break;
        }
        if job["status"].as_str() == Some("failed") {
            panic!("job failed: {job}");
        }
    }
    assert!(finished, "job did not reach downloadReady (timeout ticks)");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-jobs/{job_id}/file"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (fst, bytes, ct) = read_bytes_response(res, 4 * 1024 * 1024).await;
    assert_eq!(fst, StatusCode::OK);
    assert!(
        ct.as_deref()
            .unwrap_or("")
            .to_ascii_lowercase()
            .contains("json"),
        "content-type={ct:?}"
    );
    let body_str = String::from_utf8_lossy(&bytes);
    assert!(
        body_str.trim_start().starts_with('['),
        "expected JSON array export: {body_str:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/exports")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (est, exports) = read_json_response(res).await;
    assert_eq!(est, StatusCode::OK, "exports: {exports}");
    let items = exports["items"].as_array().expect("items array");
    assert!(
        items
            .iter()
            .any(|row| row["jobId"].as_str() == Some(job_id.as_str())),
        "export history should list jobId={job_id}: {exports}"
    );

    cleanup_jobs(&pool, &[job_uuid]).await;
    delete_workspace_fixtures(&pool, workspace_id).await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; cargo test settings_workspace_shared_audit_export_active_limit_returns_429 -- --ignored"]
async fn settings_workspace_shared_audit_export_active_limit_returns_429() {
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
    let state = contract_state(pool.clone(), secret);
    let app = build_router(state.clone());

    let workspace_id = create_workspace_and_switch_current(&app, &token).await;

    let mut job_ids: Vec<Uuid> = Vec::new();
    for i in 0..3 {
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-async")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"format":"json"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (st, j) = read_json_response(res).await;
        assert_eq!(st, StatusCode::OK, "enqueue {i}: {j}");
        job_ids.push(Uuid::parse_str(j["id"].as_str().expect("job id")).unwrap());
    }

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-async")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"format":"json"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (st, j) = read_json_response(res).await;
    assert_eq!(
        st,
        StatusCode::TOO_MANY_REQUESTS,
        "4th enqueue should hit concurrent cap: {j}"
    );
    assert_eq!(j["code"].as_str(), Some("concurrent_limit_exceeded"));

    cleanup_jobs(&pool, &job_ids).await;
    delete_workspace_fixtures(&pool, workspace_id).await;
}
