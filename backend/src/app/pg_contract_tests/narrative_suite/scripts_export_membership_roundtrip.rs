//! Script export zip respects workspace membership (EXISTS filter).

use super::super::*;
use serde_json::json;
use std::io::Cursor;
use tower::ServiceExt;
use zip::ZipArchive;

const EXPORT_OWNER: &str = "11111111-1111-4111-8111-111111111111";
const EXPORT_OUTSIDER: &str = "22222222-2222-4222-8222-222222222222";

async fn ensure_export_users(pool: &PgPool, owner_id: Uuid, outsider_id: Uuid) {
    for (id, email) in [
        (owner_id, "scripts-export-owner@example.com"),
        (outsider_id, "scripts-export-outsider@example.com"),
    ] {
        sqlx::query(
            r#"
            INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
            VALUES ($1, $2, 'contract-test-password', NOW(), NOW(), NOW())
            ON CONFLICT (id) DO NOTHING
            "#,
        )
        .bind(id)
        .bind(email)
        .execute(pool)
        .await
        .expect("auth user");
        sqlx::query(
            r#"
            INSERT INTO app_user_profile (user_id, plan_tier, daily_job_quota)
            VALUES ($1, 'free', 20)
            ON CONFLICT (user_id) DO NOTHING
            "#,
        )
        .bind(id)
        .execute(pool)
        .await
        .expect("profile");
    }
}

async fn cleanup_export_fixtures(pool: &PgPool, owner_id: Uuid, project_numeric_id: i32) {
    let _ = sqlx::query("DELETE FROM public.app_script WHERE project_id IN (SELECT id FROM public.app_project WHERE numeric_id = $1)")
        .bind(project_numeric_id)
        .execute(pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
        .bind(project_numeric_id)
        .execute(pool)
        .await;
    for user_id in [owner_id] {
        let _ = sqlx::query("DELETE FROM public.app_workspace_member WHERE user_id = $1")
            .bind(user_id)
            .execute(pool)
            .await;
    }
}

fn zip_entry_count(bytes: &[u8]) -> usize {
    let cursor = Cursor::new(bytes);
    let archive = ZipArchive::new(cursor).expect("valid zip");
    archive.len()
}

async fn export_scripts(
    app: &axum::Router,
    token: &str,
    numeric_ids: &[i32],
) -> (StatusCode, Vec<u8>) {
    let body = json!({ "numeric_ids": numeric_ids }).to_string();
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/scripts/export")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, bytes, _) = read_bytes_response(res, 2 * 1024 * 1024).await;
    (status, bytes)
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET; cargo test scripts_export_membership -- --ignored"]
async fn scripts_export_membership_roundtrip() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL");
    let secret = std::env::var("SUPABASE_JWT_SECRET").expect("SUPABASE_JWT_SECRET");
    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect");

    let owner_id = Uuid::parse_str(EXPORT_OWNER).unwrap();
    let outsider_id = Uuid::parse_str(EXPORT_OUTSIDER).unwrap();
    ensure_export_users(&pool, owner_id, outsider_id).await;

    let owner_token = jwt_fixture::encode_supabase_style(owner_id, secret.as_bytes());
    let outsider_token = jwt_fixture::encode_supabase_style(outsider_id, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let project_res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {owner_token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (project_status, project) = read_json_response(project_res).await;
    assert_eq!(project_status, StatusCode::CREATED, "project={project}");
    let project_numeric_id = project["numeric_id"].as_i64().expect("numeric_id") as i32;
    let project_uuid = project["id"].as_str().expect("project uuid");

    let script_res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/scripts"))
                .header(header::AUTHORIZATION, format!("Bearer {owner_token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "name": "pg_export_membership",
                        "content": "owner-only script body"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (script_status, script) = read_json_response(script_res).await;
    assert_eq!(script_status, StatusCode::CREATED, "script={script}");
    let script_numeric_id = script["numeric_id"].as_i64().expect("numeric_id") as i32;

    let (outsider_status, outsider_zip) =
        export_scripts(&app, &outsider_token, &[script_numeric_id]).await;
    assert_eq!(outsider_status, StatusCode::OK);
    assert_eq!(
        zip_entry_count(&outsider_zip),
        0,
        "outsider must not export scripts outside their workspace membership"
    );

    let (owner_status, owner_zip) = export_scripts(&app, &owner_token, &[script_numeric_id]).await;
    assert_eq!(owner_status, StatusCode::OK);
    assert_eq!(
        zip_entry_count(&owner_zip),
        1,
        "owner export should include script"
    );

    cleanup_export_fixtures(&pool, owner_id, project_numeric_id).await;
}
