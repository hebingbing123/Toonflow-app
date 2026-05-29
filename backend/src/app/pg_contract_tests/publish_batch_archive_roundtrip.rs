//! Batch archive publish drafts — per-id failures for optimistic UI rollback.

use super::*;
use serde_json::json;
use tower::ServiceExt;
use uuid::Uuid;

async fn cleanup_publish_batch_fixtures(
    pool: &PgPool,
    draft_ids: &[Uuid],
    project_numeric_id: i32,
) {
    for draft_id in draft_ids {
        let _ = sqlx::query("DELETE FROM public.app_publish_draft WHERE id = $1")
            .bind(draft_id)
            .execute(pool)
            .await;
    }
    let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
        .bind(project_numeric_id)
        .execute(pool)
        .await;
}

async fn create_draft(
    app: &axum::Router,
    token: &str,
    project_uuid: &str,
    title_suffix: &str,
) -> Uuid {
    let body = json!({
        "title": format!("pg batch archive {title_suffix}"),
        "description": "batch archive contract",
        "draft_status": "editing"
    });
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

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET; cargo test publish_batch_archive_roundtrip -- --ignored"]
async fn publish_batch_archive_roundtrip() {
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
                    r#"{{"name":"pg_batch_archive_{}"}}"#,
                    Uuid::new_v4().simple()
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert!(
        status == StatusCode::OK || status == StatusCode::CREATED,
        "create project: {created:?}"
    );
    let project_uuid = created["id"].as_str().expect("project uuid").to_string();
    let project_numeric_id = created["numeric_id"].as_i64().expect("numeric_id") as i32;

    let draft_a = create_draft(&app, &token, &project_uuid, "a").await;
    let draft_b = create_draft(&app, &token, &project_uuid, "b").await;
    let missing = Uuid::new_v4();

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/publish/drafts/batch-archive"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({ "draft_ids": [draft_a, draft_b, missing] }).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "batch archive: {body:?}");
    assert_eq!(
        body["archived"].as_i64(),
        Some(2),
        "archived count: {body:?}"
    );
    let failed = body["failed"].as_array().expect("failed array");
    assert_eq!(failed.len(), 1, "missing draft should fail: {body:?}");
    assert_eq!(
        failed[0]["draft_id"]
            .as_str()
            .map(|s| s.to_ascii_lowercase()),
        Some(missing.to_string().to_ascii_lowercase())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/publish/drafts/batch-archive"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(json!({ "draft_ids": [draft_a] }).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "re-archive: {body:?}");
    assert_eq!(
        body["archived"].as_i64(),
        Some(0),
        "already archived: {body:?}"
    );
    assert_eq!(body["failed"].as_array().map(|a| a.len()), Some(1));

    cleanup_publish_batch_fixtures(&pool, &[draft_a, draft_b], project_numeric_id).await;
}
