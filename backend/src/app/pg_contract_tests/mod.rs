//! PostgreSQL 契约测试（真实数据库）。
//!
//! 端到端测试覆盖核心业务场景：资产、项目、计费、叙事、制作工作台。
//!
//! 测试需要 Postgres 连接；使用临时数据库并回滚。

use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;

use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::header;
use axum::http::{Method, Request, StatusCode};
use axum::response::Response;
use serde_json::{json, Value};
use sqlx::postgres::PgPoolOptions;
use sqlx::types::Json;
use sqlx::PgPool;
use tokio::sync::RwLock;
use tower::ServiceExt;
use uuid::Uuid;

use super::build_router;
use super::jwt_fixture;
use super::vendor_credential_test_lock;
use crate::jobs::{
    JOB_KIND_ASSET_GENERATE_BATCH, JOB_KIND_ASSET_GENERATE_IMAGE, JOB_KIND_ASSET_POLISH_BATCH,
    JOB_KIND_ASSET_POLISH_PROMPT, JOB_KIND_SETTINGS_VENDOR_MODEL_TEST,
};
use crate::state::WsNotifyHub;
use crate::state::{AppState, MemoryConfig};

const MAX_JSON: usize = 65_536;
const TEST_JWT_SECRET: &[u8] = b"contract-smoke-jwt-secret-bytes-32chars!";
/// JWT `sub` and `app_project.owner_user_id` for this run.
const CONTRACT_USER_SUB: &str = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";

/// Isolated legacy ids for **`promote_staging_populates_assets_and_links`** (avoid API allocator range).
const PROMO_LEGACY_USER: i32 = 5_010_000;
const PROMO_PROJECT_LEG: i32 = 5_010_001;
const PROMO_SCRIPT_LEG: i32 = 5_010_002;
const PROMO_ASSET_LEG: i32 = 5_010_003;
const PROMO_ART_STYLE_LEG: i32 = 5_010_004;
const PROMO_IMAGE_LEG: i32 = 5_010_005;

async fn cleanup_promote_staging_fixtures(pool: &PgPool) {
    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let _ = sqlx::query("DELETE FROM public.app_user_prompt WHERE owner_user_id = $1")
        .bind(sub)
        .execute(pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(PROMO_PROJECT_LEG)
        .execute(pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_art_style WHERE legacy_id = $1")
        .bind(PROMO_ART_STYLE_LEG)
        .execute(pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.legacy_user_map WHERE legacy_user_id = $1")
        .bind(PROMO_LEGACY_USER)
        .execute(pool)
        .await;
    let _ = sqlx::query(
        r#"DELETE FROM legacy_staging.snapshot
           WHERE source_row_key IN ('pg_promote_proj','pg_promote_script','pg_promote_asset','pg_promote_script_asset','pg_promote_art_style','pg_promote_prompt','pg_promote_image')"#,
    )
    .execute(pool)
    .await;
}

async fn cleanup_quality_reviews(pool: &PgPool, review_ids: &[Uuid]) {
    if review_ids.is_empty() {
        return;
    }

    let _ = sqlx::query("DELETE FROM public.app_quality_review WHERE id = ANY($1)")
        .bind(review_ids)
        .execute(pool)
        .await;
}

async fn cleanup_jobs(pool: &PgPool, job_ids: &[Uuid]) {
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

async fn cleanup_billing_webhook_events(pool: &PgPool, provider_event_ids: &[String]) {
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

fn test_addr() -> SocketAddr {
    SocketAddr::from(([127, 0, 0, 1], 42_043))
}

async fn read_json_response(res: Response) -> (StatusCode, Value) {
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

async fn read_bytes_response(res: Response, max: usize) -> (StatusCode, Vec<u8>, Option<String>) {
    let status = res.status();
    let ct = res
        .headers()
        .get(header::CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .map(str::to_string);
    let bytes = axum::body::to_bytes(res.into_body(), max).await.unwrap();
    (status, bytes.to_vec(), ct)
}

fn contract_state(pool: sqlx::PgPool, jwt_secret: String) -> AppState {
    AppState {
        pool: Some(pool),
        jwt_secret: Some(jwt_secret.into_bytes()),
        llm: None,
        http_client: reqwest::Client::new(),
        notify: WsNotifyHub::new(),
        memory_config: Arc::new(RwLock::new(MemoryConfig::default_legacy())),
        switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
        local_asset_image_dir: None,
        local_art_style_cover_dir: None,
    }
}

fn smoke_state() -> AppState {
    AppState {
        pool: None,
        jwt_secret: Some(TEST_JWT_SECRET.to_vec()),
        llm: None,
        http_client: reqwest::Client::new(),
        notify: WsNotifyHub::new(),
        memory_config: Arc::new(RwLock::new(MemoryConfig::default_legacy())),
        switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
        local_asset_image_dir: None,
        local_art_style_cover_dir: None,
    }
}

fn test_jwt(sub: Uuid) -> String {
    jwt_fixture::encode_supabase_style(sub, TEST_JWT_SECRET)
}

async fn oneshot_json(req: Request<Body>) -> (StatusCode, Value) {
    let app = build_router(smoke_state());
    let res = app.oneshot(req).await.unwrap();
    read_json_response(res).await
}

async fn get_json(uri: &str) -> (StatusCode, Value) {
    oneshot_json(
        Request::builder()
            .uri(uri)
            .extension(ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await
}

async fn get_json_bearer(uri: &str, token: &str) -> (StatusCode, Value) {
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

async fn post_json(uri: &str, json_body: &str) -> (StatusCode, Value) {
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

async fn post_json_bearer(uri: &str, token: &str, json_body: &str) -> (StatusCode, Value) {
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

fn contract_state_with_local_dir(pool: sqlx::PgPool, jwt_secret: String, dir: PathBuf) -> AppState {
    AppState {
        pool: Some(pool),
        jwt_secret: Some(jwt_secret.into_bytes()),
        llm: None,
        http_client: reqwest::Client::new(),
        notify: WsNotifyHub::new(),
        memory_config: Arc::new(RwLock::new(MemoryConfig::default_legacy())),
        switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
        local_asset_image_dir: Some(dir),
        local_art_style_cover_dir: None,
    }
}

fn contract_state_with_local_art_style_dir(
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
        memory_config: Arc::new(RwLock::new(MemoryConfig::default_legacy())),
        switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
        local_asset_image_dir: None,
        local_art_style_cover_dir: Some(dir),
    }
}

mod assets_suite;
mod business_suite;
mod content_suite;
mod narrative_suite;
mod ops_suite;
mod production_suite;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
async fn projects_create_stats_delete_roundtrip() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");
    let pool_sql = pool.clone();

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool, secret));

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
    assert_eq!(status, StatusCode::CREATED, "body={created}");
    let legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;
    let project_uuid = created["id"].as_str().expect("project uuid");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/projects/{project_uuid}/stats"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, stats) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "stats={stats}");
    assert_eq!(stats["script_count"], 0);
    assert_eq!(stats["storyboard_count"], 0);
    assert_eq!(stats["role_count"], 0);
    assert_eq!(stats["novel_count"], 0);
    assert_eq!(stats["video_count"], 0);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, assets_body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "assets={assets_body}");
    assert!(assets_body["items"].is_array());
    assert_eq!(
        assets_body["total"].as_i64().unwrap_or(-1),
        assets_body["items"]
            .as_array()
            .map(|a| a.len() as i64)
            .unwrap_or(-2),
        "unpaged list: total matches items length"
    );

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
    let (status, script_row) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "script={script_row}");
    let script_leg = script_row["legacy_id"].as_i64().expect("script legacy_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"name":"pg_contract_role_asset","type":"role"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, asset_row) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "asset={asset_row}");
    let asset_leg = asset_row["legacy_id"].as_i64().expect("asset legacy_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/{asset_leg}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, one_asset) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "one_asset={one_asset}");
    assert_eq!(
        one_asset["legacy_id"].as_i64().expect("legacy_id"),
        i64::from(asset_leg)
    );
    assert_eq!(one_asset["name"].as_str(), Some("pg_contract_role_asset"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/corner-scape"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, corner1) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "corner1={corner1}");
    let c1 = corner1["items"].as_array().expect("corner1 items");
    assert_eq!(c1.len(), 1);
    assert_eq!(
        c1[0]["legacy_id"].as_i64().expect("leg"),
        i64::from(asset_leg)
    );
    assert_eq!(c1[0]["asset_type"].as_str(), Some("role"));
    assert!(
        c1[0]["history_images"]
            .as_array()
            .is_some_and(|a| a.is_empty()),
        "history_images empty before app_asset_image row"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/{asset_leg}/images"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"file_path":"pg_contract/corner_hist.png","state":"已完成","sort_index":0}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, img_row) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "img_row={img_row}");
    assert_eq!(
        img_row["file_path"].as_str(),
        Some("pg_contract/corner_hist.png")
    );
    assert_eq!(img_row["state"].as_str(), Some("已完成"));

    let img_uuid = img_row["id"].as_str().expect("image id");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/{asset_leg}/images"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_img) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list_img={list_img}");
    assert!(
        list_img["cover_legacy_image_id"].is_null(),
        "API-created asset has no metadata.imageId cover"
    );
    let lim = list_img["items"].as_array().expect("image list items");
    assert_eq!(lim.len(), 1);
    assert_eq!(lim[0]["id"].as_str(), Some(img_uuid));
    assert_eq!(lim[0]["selected"], false);
    assert!(
        lim[0]["legacy_image_id"].is_null(),
        "API-created image has no legacy_image_id"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/get-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"assetsId":{asset_leg}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, legacy_get_image) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "legacy_get_image={legacy_get_image}"
    );
    assert_eq!(legacy_get_image["id"].as_i64(), Some(i64::from(asset_leg)));
    assert!(legacy_get_image["imageId"].is_null());
    let legacy_temp = legacy_get_image["tempAssets"]
        .as_array()
        .expect("legacy get-image tempAssets");
    assert_eq!(legacy_temp.len(), 1);
    assert_eq!(
        legacy_temp[0]["assetsId"].as_i64(),
        Some(i64::from(asset_leg))
    );
    assert_eq!(legacy_temp[0]["selected"], false);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/{asset_leg}/images/{img_uuid}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, one_img) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "one_img={one_img}");
    assert_eq!(one_img["id"].as_str(), Some(img_uuid));
    assert_eq!(
        one_img["file_path"].as_str(),
        Some("pg_contract/corner_hist.png")
    );
    assert_eq!(one_img["state"].as_str(), Some("已完成"));
    assert!(one_img["legacy_image_id"].is_null());

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/{asset_leg}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"cover_legacy_image_id":424242}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, bad_cov) = read_json_response(res).await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "bad_cov={bad_cov}");
    assert_eq!(bad_cov["code"].as_str(), Some("bad_request"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/corner-scape"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, corner1_hist) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "corner1_hist={corner1_hist}");
    let c1h = corner1_hist["items"]
        .as_array()
        .expect("corner1_hist items");
    assert_eq!(c1h.len(), 1);
    let hi = c1h[0]["history_images"].as_array().expect("history");
    assert_eq!(hi.len(), 1);
    assert_eq!(
        hi[0]["file_path"].as_str(),
        Some("pg_contract/corner_hist.png")
    );
    assert_eq!(hi[0]["state"].as_str(), Some("已完成"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/{asset_leg}/images/{img_uuid}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"state":""}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patched={patched}");
    assert!(patched["state"].is_null());

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/corner-scape"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, corner_no_hist) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "corner_no_hist={corner_no_hist}");
    let cn = corner_no_hist["items"].as_array().expect("items");
    assert_eq!(cn.len(), 1);
    assert!(
        cn[0]["history_images"]
            .as_array()
            .is_some_and(|a| a.is_empty()),
        "NULL state excludes row from corner-scape history"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/{asset_leg}/images/{img_uuid}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"state":"已完成"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, restored) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "restored={restored}");
    assert_eq!(restored["state"].as_str(), Some("已完成"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"name":"pg_contract_scene_asset","type":"scene"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, scene_row) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "scene_row={scene_row}");
    let scene_leg = scene_row["legacy_id"].as_i64().expect("scene legacy_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/corner-scape"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, corner2) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "corner2={corner2}");
    let c2 = corner2["items"].as_array().expect("corner2 items");
    assert_eq!(c2.len(), 2);
    assert_eq!(c2[0]["asset_type"].as_str(), Some("role"));
    assert_eq!(c2[1]["asset_type"].as_str(), Some("scene"));
    assert_eq!(c2[0]["history_images"].as_array().map(|a| a.len()), Some(1));
    assert!(
        c2[1]["history_images"]
            .as_array()
            .is_some_and(|a| a.is_empty()),
        "scene has no history row"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/corner-scape"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"types":["scene"]}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, corner_scene_only) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "corner_scene_only={corner_scene_only}"
    );
    let cs = corner_scene_only["items"]
        .as_array()
        .expect("corner scene filter");
    assert_eq!(cs.len(), 1);
    assert_eq!(
        cs[0]["legacy_id"].as_i64().expect("leg"),
        i64::from(scene_leg)
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/corner-scape"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"types":["scene"," SCENE ","scene",""]}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, corner_scene_dedup) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "corner_scene_dedup={corner_scene_dedup}"
    );
    let csd = corner_scene_dedup["items"]
        .as_array()
        .expect("corner scene dedup filter");
    assert_eq!(csd.len(), 1);
    assert_eq!(
        csd[0]["legacy_id"].as_i64().expect("leg"),
        i64::from(scene_leg)
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/corner-scape"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"types":[" ","\n\t",""]}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, corner_blank_types) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "corner_blank_types={corner_blank_types}"
    );
    assert_eq!(
        corner_blank_types["items"].as_array().map(|a| a.len()),
        Some(2),
        "blank-only types should behave like no filter"
    );

    let n = sqlx::query(
        r#"
        UPDATE app_asset a
        SET metadata = jsonb_build_object('assetsId', 999999)
        FROM app_project p
        WHERE a.project_id = p.id
          AND p.legacy_id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(legacy_id)
    .bind(sub)
    .bind(scene_leg)
    .execute(&pool_sql)
    .await
    .expect("mark scene row as child asset via metadata.assetsId");
    assert_eq!(n.rows_affected(), 1, "expected one scene row updated");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/corner-scape"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, corner_child_hidden) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "corner_child_hidden={corner_child_hidden}"
    );
    let ch = corner_child_hidden["items"]
        .as_array()
        .expect("corner after child metadata");
    assert_eq!(ch.len(), 1);
    assert_eq!(
        ch[0]["legacy_id"].as_i64().expect("leg"),
        i64::from(asset_leg)
    );
    assert_eq!(ch[0]["history_images"].as_array().map(|a| a.len()), Some(1));

    let n = sqlx::query(
        r#"
        UPDATE app_asset a
        SET metadata = '{}'::jsonb
        FROM app_project p
        WHERE a.project_id = p.id
          AND p.legacy_id = $1
          AND p.owner_user_id = $2
          AND a.legacy_id = $3
        "#,
    )
    .bind(legacy_id)
    .bind(sub)
    .bind(scene_leg)
    .execute(&pool_sql)
    .await
    .expect("reset scene metadata");
    assert_eq!(n.rows_affected(), 1);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/corner-scape"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, corner_restored) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "corner_restored={corner_restored}");
    assert_eq!(
        corner_restored["items"].as_array().map(|a| a.len()),
        Some(2)
    );
    let cr = corner_restored["items"]
        .as_array()
        .expect("corner restored items");
    assert_eq!(cr[0]["history_images"].as_array().map(|a| a.len()), Some(1));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/projects/{project_uuid}/stats"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, stats_mid) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "stats_mid={stats_mid}");
    assert_eq!(stats_mid["script_count"], 1);
    assert_eq!(stats_mid["storyboard_count"], 0);
    assert_eq!(stats_mid["role_count"], 1);
    assert_eq!(stats_mid["novel_count"], 0);
    assert_eq!(stats_mid["video_count"], 0);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/projects/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, sum_mid) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "sum_mid={sum_mid}");
    assert_eq!(sum_mid["video_count"], 0);
    let g_role = sum_mid["role_count"].as_i64().expect("summary role_count");
    let p_role = stats_mid["role_count"].as_i64().expect("stats role_count");
    assert!(
        g_role >= p_role,
        "projects/summary role_count ({g_role}) should be >= per-project stats ({p_role})"
    );
    let g_script = sum_mid["script_count"]
        .as_i64()
        .expect("summary script_count");
    let p_script = stats_mid["script_count"]
        .as_i64()
        .expect("stats script_count");
    assert!(
        g_script >= p_script,
        "projects/summary script_count ({g_script}) should be >= per-project stats ({p_script})"
    );
    let g_asset = sum_mid["asset_count"]
        .as_i64()
        .expect("summary asset_count");
    assert!(
        g_asset >= 1,
        "expected at least one app_asset row in summary"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets?asset_type=role&name=pg_contract"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, by_type_name) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "by_type_name={by_type_name}");
    assert_eq!(by_type_name["total"], 1);
    let items = by_type_name["items"].as_array().expect("items");
    assert_eq!(items.len(), 1);
    assert_eq!(
        items[0]["legacy_id"].as_i64().expect("legacy_id"),
        i64::from(asset_leg)
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets?asset_type=tool&name=pg_contract"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, wrong_type) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "wrong_type={wrong_type}");
    assert_eq!(wrong_type["total"], 0);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets?script_legacy_id={script_leg}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, linked_before) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "linked_before={linked_before}");
    assert_eq!(linked_before["total"], 0);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PUT)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/scripts/{script_leg}/assets/{asset_leg}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, empty_put) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NO_CONTENT, "put body={empty_put}");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets?script_legacy_id={script_leg}&limit=10&page=1"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, linked_after) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "linked_after={linked_after}");
    assert_eq!(linked_after["total"], 1);
    assert_eq!(
        linked_after["items"]
            .as_array()
            .map(|a| a.len())
            .unwrap_or(0),
        1
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/scripts/{script_leg}/assets/{asset_leg}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, empty_unlink) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NO_CONTENT, "unlink={empty_unlink}");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets?script_legacy_id={script_leg}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, unlinked) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "unlinked={unlinked}");
    assert_eq!(unlinked["total"], 0);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/novels"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"chapter":"pg_contract_chap"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, novel_row) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "novel_row={novel_row}");
    let novel_leg = novel_row["legacy_id"].as_i64().expect("novel legacy_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/projects/{project_uuid}/stats"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, stats_with_novel) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "stats_with_novel={stats_with_novel}"
    );
    assert_eq!(stats_with_novel["novel_count"], 1);
    assert_eq!(stats_with_novel["role_count"], 1);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novels?search=pg_contract&page=1&limit=10"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, novel_list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "novel_list={novel_list}");
    assert!(novel_list["total"].as_i64().unwrap_or(0) >= 1);

    // REST `GET/POST/PATCH/DELETE …/projects/{uuid}/novels*` parity on the same rows.
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novels?page=1&limit=200"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_all) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list_all={list_all}");
    let rows = list_all["items"].as_array().expect("novel items");
    assert!(
        rows.iter()
            .any(|r| r["legacy_id"].as_i64() == Some(i64::from(novel_leg))),
        "expected novel legacy_id in list: {list_all}"
    );
    assert!(
        rows.iter().any(|r| {
            r["legacy_id"].as_i64() == Some(i64::from(novel_leg))
                && r["chapter_index"].is_number()
                && r["chapter"].is_string()
        }),
        "expected index/chapter fields (legacy get-novel-index shape): {list_all}"
    );

    let non_zero: Vec<&serde_json::Value> = rows
        .iter()
        .filter(|r| {
            r["legacy_id"].as_i64() == Some(i64::from(novel_leg))
                && r["event_state"].as_i64().unwrap_or(0) != 0
        })
        .collect();
    assert!(
        non_zero.is_empty(),
        "fresh novels should not expose non-zero event_state: {list_all}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novels?page=1&limit=10"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, get_pg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get_novel={get_pg}");
    assert_eq!(get_pg["total"].as_i64(), Some(1));
    let page_rows = get_pg["items"].as_array().expect("paged items");
    assert_eq!(
        page_rows[0]["legacy_id"].as_i64(),
        Some(i64::from(novel_leg))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/novels"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"chapter_index":99,"reel":"lr","chapter":"pg_legacy_add_chapter","chapter_data":"d0"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "add novel via REST");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novels?page=1&limit=10"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, two_rows) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "two_rows={two_rows}");
    assert_eq!(two_rows["total"].as_i64(), Some(2));
    let added_leg = two_rows["items"]
        .as_array()
        .expect("items")
        .iter()
        .find(|r| r["chapter"].as_str() == Some("pg_legacy_add_chapter"))
        .expect("added chapter row")["legacy_id"]
        .as_i64()
        .expect("added legacy id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novels/{added_leg}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"chapter":"pg_legacy_patched","chapter_data":"d1","reel":"","event":""}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patch novel");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novels?search=pg_legacy_pat&page=1&limit=10"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, search_pg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "search_novel={search_pg}");
    assert!(search_pg["total"].as_i64().unwrap_or(0) >= 1);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novels/{added_leg}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), StatusCode::NO_CONTENT, "delete novel");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novels?page=1&limit=10"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, one_again) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "one_again={one_again}");
    assert_eq!(one_again["total"].as_i64(), Some(1));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novels/{novel_leg}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, one_novel) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "one_novel={one_novel}");
    assert_eq!(one_novel["chapter"].as_str(), Some("pg_contract_chap"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novels/{novel_leg}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"chapter":"pg_contract_patched"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched_novel) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patched={patched_novel}");
    assert_eq!(
        patched_novel["chapter"].as_str(),
        Some("pg_contract_patched")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novels/{novel_leg}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, del_novel) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NO_CONTENT, "del_novel={del_novel}");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/projects/{project_uuid}/stats"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, stats_no_novel) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "stats_no_novel={stats_no_novel}");
    assert_eq!(stats_no_novel["novel_count"], 0);
    assert_eq!(stats_no_novel["role_count"], 1);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novels/{novel_leg}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, novel_gone) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NOT_FOUND, "novel_gone={novel_gone}");

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
    let (status, empty) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NO_CONTENT, "body={empty}");

    let res = app
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/projects/{project_uuid}/stats"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, err) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NOT_FOUND, "err={err}");
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn legacy_project_crud_roundtrip() {
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
    let initial_name = format!("pg_legacy_project_{unique_suffix}");
    let updated_name = format!("{initial_name}_updated");

    let create_body = json!({
        "name": initial_name,
        "intro": "legacy intro",
        "project_type": "short-drama",
        "art_style": "ink",
        "director_manual": "story-manual",
        "video_ratio": "9:16",
        "image_model": "dalle-3",
        "video_model": "runway",
        "image_quality": "hd",
        "mode": "novel",
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
    let legacy_id = added["legacy_id"].as_i64().expect("legacy_id") as i32;

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
        created_row["legacy_id"].as_i64(),
        Some(i64::from(legacy_id))
    );
    assert_eq!(created_row["intro"].as_str(), Some("legacy intro"));
    assert_eq!(created_row["project_type"].as_str(), Some("short-drama"));
    assert_eq!(created_row["mode"].as_str(), Some("novel"));
    assert_eq!(created_row["art_style"].as_str(), Some("ink"));
    assert_eq!(
        created_row["director_manual"].as_str(),
        Some("story-manual")
    );
    assert_eq!(created_row["video_ratio"].as_str(), Some("9:16"));
    assert_eq!(created_row["image_model"].as_str(), Some("dalle-3"));
    assert_eq!(created_row["video_model"].as_str(), Some("runway"));
    assert_eq!(created_row["image_quality"].as_str(), Some("hd"));

    let stored_mode: Option<String> = sqlx::query_scalar(
        "SELECT mode FROM public.app_project WHERE owner_user_id = $1 AND legacy_id = $2",
    )
    .bind(sub)
    .bind(legacy_id)
    .fetch_optional(&pool)
    .await
    .expect("select initial mode");
    assert_eq!(stored_mode.as_deref(), Some("novel"));

    let patch_body = json!({
        "name": updated_name,
        "intro": Value::Null,
        "project_type": "feature",
        "art_style": Value::Null,
        "director_manual": "revised-manual",
        "video_ratio": "16:9",
        "image_model": "flux",
        "video_model": "kling",
        "image_quality": "standard",
        "mode": "professional",
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
                .find(|row| row["legacy_id"].as_i64() == Some(i64::from(legacy_id)))
        })
        .cloned()
        .expect("edited project row");
    assert_eq!(edited_row["name"].as_str(), Some(updated_name.as_str()));
    assert!(edited_row["intro"].is_null());
    assert_eq!(edited_row["project_type"].as_str(), Some("feature"));
    assert_eq!(edited_row["mode"].as_str(), Some("professional"));
    assert!(edited_row["art_style"].is_null());
    assert_eq!(
        edited_row["director_manual"].as_str(),
        Some("revised-manual")
    );
    assert_eq!(edited_row["video_ratio"].as_str(), Some("16:9"));
    assert_eq!(edited_row["image_model"].as_str(), Some("flux"));
    assert_eq!(edited_row["video_model"].as_str(), Some("kling"));
    assert_eq!(edited_row["image_quality"].as_str(), Some("standard"));

    let stored_mode: Option<String> = sqlx::query_scalar(
        "SELECT mode FROM public.app_project WHERE owner_user_id = $1 AND legacy_id = $2",
    )
    .bind(sub)
    .bind(legacy_id)
    .fetch_optional(&pool)
    .await
    .expect("select edited mode");
    assert_eq!(stored_mode.as_deref(), Some("professional"));

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
            .any(|row| row["legacy_id"].as_i64() == Some(i64::from(legacy_id)))
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

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn projects_patch_partial_fields_roundtrip() {
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

    let create_body = format!(
        r#"{{
            "name":"pg_general_project_{}",
            "intro":"before update",
            "project_type":"movie",
            "art_style":"orig-style",
            "mode":"orig-mode",
            "video_ratio":"9:16"
        }}"#,
        Uuid::new_v4().simple()
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(create_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "created={created}");
    let project_uuid = Uuid::parse_str(created["id"].as_str().expect("project id")).unwrap();

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, before_update) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "before_update={before_update}");
    let proj = &before_update["project"];
    assert_eq!(proj["intro"].as_str(), Some("before update"));
    assert_eq!(proj["mode"].as_str(), Some("orig-mode"));
    assert_eq!(proj["art_style"].as_str(), Some("orig-style"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, empty_patch) = read_json_response(res).await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "empty_patch={empty_patch}");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"intro":"after update","mode":"legacy-mode","art_style":null,"video_ratio":"1:1","project_type":"series"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patched={patched}");
    assert_eq!(patched["intro"].as_str(), Some("after update"));
    assert_eq!(patched["mode"].as_str(), Some("legacy-mode"));
    assert!(patched["art_style"].is_null());
    assert_eq!(patched["video_ratio"].as_str(), Some("1:1"));
    assert_eq!(patched["project_type"].as_str(), Some("series"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, after_update) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "after_update={after_update}");
    let row = &after_update["project"];
    assert_eq!(
        row["name"].as_str(),
        created["name"].as_str(),
        "PATCH must preserve untouched fields"
    );
    assert_eq!(row["intro"].as_str(), Some("after update"));
    assert_eq!(row["mode"].as_str(), Some("legacy-mode"));
    assert!(row["art_style"].is_null());
    assert_eq!(row["video_ratio"].as_str(), Some("1:1"));
    assert_eq!(row["project_type"].as_str(), Some("series"));

    let stored: (Option<String>, Option<String>, Option<String>, Option<String>) = sqlx::query_as(
        "SELECT intro, mode, art_style, project_type FROM public.app_project WHERE id = $1 AND owner_user_id = $2",
    )
    .bind(project_uuid)
    .bind(sub)
    .fetch_one(&pool)
    .await
    .expect("select updated project");
    assert_eq!(stored.0.as_deref(), Some("after update"));
    assert_eq!(stored.1.as_deref(), Some("legacy-mode"));
    assert_eq!(stored.2, None);
    assert_eq!(stored.3.as_deref(), Some("series"));

    let _ = sqlx::query("DELETE FROM public.app_project WHERE id = $1")
        .bind(project_uuid)
        .execute(&pool)
        .await;
}
