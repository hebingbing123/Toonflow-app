//! Shared helpers and fixtures for PostgreSQL contract tests (`pg_contract_tests`).

use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;

pub(crate) use axum::body::Body;
pub(crate) use axum::extract::ConnectInfo;
pub(crate) use axum::http::header;
pub(crate) use axum::http::{Method, Request, StatusCode};
pub(crate) use axum::response::Response;
pub(crate) use serde_json::Value;
pub(crate) use sqlx::PgPool;
use tokio::sync::RwLock;
pub(crate) use tower::ServiceExt;
pub(crate) use uuid::Uuid;

pub(crate) use crate::app::billing_webhook_events_list_env::BillingWebhookEventsListEnvGuard;
pub(crate) use crate::app::build_router;
pub(crate) use crate::app::jwt_fixture;
pub(crate) use crate::app::vendor_credential_test_lock;
pub(crate) use crate::jobs::{
    JOB_KIND_ASSET_GENERATE_BATCH, JOB_KIND_ASSET_GENERATE_IMAGE, JOB_KIND_ASSET_POLISH_BATCH,
    JOB_KIND_ASSET_POLISH_PROMPT, JOB_KIND_SETTINGS_VENDOR_MODEL_TEST,
};
use crate::state::AppState;
pub(crate) use crate::state::MemoryConfig;
use crate::state::WsNotifyHub;
pub(crate) use sqlx::postgres::PgPoolOptions;
pub(crate) use sqlx::types::Json;

pub(crate) const MAX_JSON: usize = 65_536;
pub(crate) const TEST_JWT_SECRET: &[u8] = b"contract-smoke-jwt-secret-bytes-32chars!";
/// JWT `sub` and `app_project.owner_user_id` for this run.
pub(crate) const CONTRACT_USER_SUB: &str = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";

/// Isolated numeric ids for **`promote_staging_populates_assets_and_links`** (avoid API allocator range).
pub(crate) const PROMO_IMPORT_USER: i32 = 5_010_000;
pub(crate) const PROMO_PROJECT_LEG: i32 = 5_010_001;
pub(crate) const PROMO_SCRIPT_LEG: i32 = 5_010_002;
pub(crate) const PROMO_ASSET_LEG: i32 = 5_010_003;
pub(crate) const PROMO_ART_STYLE_LEG: i32 = 5_010_004;
pub(crate) const PROMO_IMAGE_LEG: i32 = 5_010_005;

pub(crate) async fn cleanup_promote_staging_fixtures(pool: &PgPool) {
    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let _ = sqlx::query("DELETE FROM public.app_user_prompt WHERE owner_user_id = $1")
        .bind(sub)
        .execute(pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
        .bind(PROMO_PROJECT_LEG)
        .execute(pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_art_style WHERE numeric_id = $1")
        .bind(PROMO_ART_STYLE_LEG)
        .execute(pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.import_user_map WHERE import_user_id = $1")
        .bind(PROMO_IMPORT_USER)
        .execute(pool)
        .await;
    let _ = sqlx::query(
        r#"DELETE FROM import_staging.snapshot
           WHERE source_row_key IN ('pg_promote_proj','pg_promote_script','pg_promote_asset','pg_promote_script_asset','pg_promote_art_style','pg_promote_prompt','pg_promote_image')"#,
    )
    .execute(pool)
    .await;
}

pub(crate) async fn cleanup_quality_reviews(pool: &PgPool, review_ids: &[Uuid]) {
    if review_ids.is_empty() {
        return;
    }

    let _ = sqlx::query("DELETE FROM public.app_quality_review WHERE id = ANY($1)")
        .bind(review_ids)
        .execute(pool)
        .await;
}

pub(crate) async fn cleanup_llm_usage_rows_for_jobs(pool: &PgPool, job_ids: &[Uuid]) {
    if job_ids.is_empty() {
        return;
    }

    let _ = sqlx::query("DELETE FROM public.app_llm_usage_log WHERE job_id = ANY($1)")
        .bind(job_ids)
        .execute(pool)
        .await;
}

pub(crate) async fn cleanup_jobs(pool: &PgPool, job_ids: &[Uuid]) {
    if job_ids.is_empty() {
        return;
    }

    let _ = sqlx::query("DELETE FROM public.app_usage_event WHERE source_job_id = ANY($1)")
        .bind(job_ids)
        .execute(pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_generation_job WHERE id = ANY($1)")
        .bind(job_ids)
        .execute(pool)
        .await;
}

pub(crate) async fn cleanup_billing_webhook_events(pool: &PgPool, provider_event_ids: &[String]) {
    if provider_event_ids.is_empty() {
        return;
    }

    let _ = sqlx::query(
        "DELETE FROM public.app_billing_webhook_event WHERE provider_event_id = ANY($1)",
    )
    .bind(provider_event_ids)
    .execute(pool)
    .await;
}

pub(crate) fn test_addr() -> SocketAddr {
    SocketAddr::from(([127, 0, 0, 1], 42_043))
}

pub(crate) async fn read_json_response(res: Response) -> (StatusCode, Value) {
    let status = res.status();
    let bytes = axum::body::to_bytes(res.into_body(), MAX_JSON)
        .await
        .unwrap();
    let v = if bytes.is_empty() {
        Value::Null
    } else {
        serde_json::from_slice(&bytes).expect("response json")
    };
    (status, v)
}

pub(crate) async fn read_bytes_response(
    res: Response,
    max: usize,
) -> (StatusCode, Vec<u8>, Option<String>) {
    let status = res.status();
    let ct = res
        .headers()
        .get(header::CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .map(str::to_string);
    let bytes = axum::body::to_bytes(res.into_body(), max).await.unwrap();
    (status, bytes.to_vec(), ct)
}

pub(crate) fn contract_state(pool: sqlx::PgPool, jwt_secret: String) -> AppState {
    AppState {
        pool: Some(pool),
        jwt_secret: Some(jwt_secret.into_bytes()),
        llm: None,
        http_client: reqwest::Client::new(),
        notify: WsNotifyHub::new(),
        memory_config: Arc::new(RwLock::new(MemoryConfig::default_seeded())),
        switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
        local_asset_image_dir: None,
        local_art_style_cover_dir: None,
        local_video_export_dir: None,
    }
}

pub(crate) fn smoke_state() -> AppState {
    AppState {
        pool: None,
        jwt_secret: Some(TEST_JWT_SECRET.to_vec()),
        llm: None,
        http_client: reqwest::Client::new(),
        notify: WsNotifyHub::new(),
        memory_config: Arc::new(RwLock::new(MemoryConfig::default_seeded())),
        switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
        local_asset_image_dir: None,
        local_art_style_cover_dir: None,
        local_video_export_dir: None,
    }
}

pub(crate) fn test_jwt(sub: Uuid) -> String {
    jwt_fixture::encode_supabase_style(sub, TEST_JWT_SECRET)
}

pub(crate) async fn oneshot_json(req: Request<Body>) -> (StatusCode, Value) {
    let app = build_router(smoke_state());
    let res = app.oneshot(req).await.unwrap();
    read_json_response(res).await
}

pub(crate) async fn get_json(uri: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .uri(uri)
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await
}

pub(crate) async fn get_json_bearer(uri: &str, token: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .uri(uri)
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await
}

pub(crate) async fn post_json(uri: &str, json_body: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .method(Method::POST)
            .uri(uri)
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(json_body.to_string()))
            .unwrap(),
    )
    .await
}

pub(crate) async fn post_json_bearer(
    uri: &str,
    token: &str,
    json_body: &str,
) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .method(Method::POST)
            .uri(uri)
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(json_body.to_string()))
            .unwrap(),
    )
    .await
}

pub(crate) fn contract_state_with_local_dir(
    pool: sqlx::PgPool,
    jwt_secret: String,
    dir: PathBuf,
) -> AppState {
    AppState {
        pool: Some(pool),
        jwt_secret: Some(jwt_secret.into_bytes()),
        llm: None,
        http_client: reqwest::Client::new(),
        notify: WsNotifyHub::new(),
        memory_config: Arc::new(RwLock::new(MemoryConfig::default_seeded())),
        switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
        local_asset_image_dir: Some(dir),
        local_art_style_cover_dir: None,
        local_video_export_dir: None,
    }
}

pub(crate) fn contract_state_with_local_art_style_dir(
    pool: sqlx::PgPool,
    jwt_secret: String,
    dir: PathBuf,
) -> AppState {
    AppState {
        pool: Some(pool),
        jwt_secret: Some(jwt_secret.into_bytes()),
        llm: None,
        http_client: reqwest::Client::new(),
        notify: WsNotifyHub::new(),
        memory_config: Arc::new(RwLock::new(MemoryConfig::default_seeded())),
        switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
        local_asset_image_dir: None,
        local_art_style_cover_dir: Some(dir),
        local_video_export_dir: None,
    }
}
