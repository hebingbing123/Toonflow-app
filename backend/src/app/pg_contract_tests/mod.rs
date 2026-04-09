use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;

use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::header;
use axum::http::{Method, Request, StatusCode};
use axum::response::Response;
use serde_json::Value;
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
use crate::notify_hub::WsNotifyHub;
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

mod content_suite;
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

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/projects/legacy/{legacy_id}/stats"))
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
                .uri(format!("/api/v1/projects/legacy/{legacy_id}/assets"))
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
                .uri(format!("/api/v1/projects/legacy/{legacy_id}/scripts"))
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
                .uri(format!("/api/v1/projects/legacy/{legacy_id}/assets"))
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}/images"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}/images"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}/images/{img_uuid}"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}/images/{img_uuid}"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}/images/{img_uuid}"
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
                .uri(format!("/api/v1/projects/legacy/{legacy_id}/assets"))
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets/corner-scape"
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
                .uri(format!("/api/v1/projects/legacy/{legacy_id}/stats"))
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
                    "/api/v1/projects/legacy/{legacy_id}/assets?asset_type=role&name=pg_contract"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets?asset_type=tool&name=pg_contract"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets?script_legacy_id={script_leg}"
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
                    "/api/v1/projects/legacy/{legacy_id}/scripts/{script_leg}/assets/{asset_leg}"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets?script_legacy_id={script_leg}&limit=10&page=1"
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
                    "/api/v1/projects/legacy/{legacy_id}/scripts/{script_leg}/assets/{asset_leg}"
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
                    "/api/v1/projects/legacy/{legacy_id}/assets?script_legacy_id={script_leg}"
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
                .uri(format!("/api/v1/projects/legacy/{legacy_id}/novels"))
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
                .uri(format!("/api/v1/projects/legacy/{legacy_id}/stats"))
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
                    "/api/v1/projects/legacy/{legacy_id}/novels?search=pg_contract&page=1&limit=10"
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

    // Legacy POST `/api/v1/novels/*` (Electron-shaped) round-trip vs same `app_novel` rows.
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/get-novel-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"projectId":{legacy_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, legacy_data) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "legacy_data={legacy_data}");
    let rows = legacy_data["data"].as_array().expect("legacy data array");
    assert!(
        rows.iter()
            .any(|r| { r["legacy_id"].as_i64() == Some(i64::from(novel_leg)) }),
        "expected REST novel legacy_id in get-novel-data: {legacy_data}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/get-novel-index")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"projectId":{legacy_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, legacy_idx) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "legacy_idx={legacy_idx}");
    let idx_rows = legacy_idx["data"].as_array().expect("legacy index array");
    assert!(
        idx_rows
            .iter()
            .any(|r| r["id"].as_i64() == Some(i64::from(novel_leg))),
        "expected novel_leg in get-novel-index: {legacy_idx}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/get-novel-event-state")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"ids":[{novel_leg}]}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, legacy_event_state) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "legacy_event_state={legacy_event_state}"
    );
    let event_rows = legacy_event_state["data"]
        .as_array()
        .expect("legacy event state array");
    assert!(
        event_rows.is_empty(),
        "freshly created novels should not expose non-zero event_state rows: {legacy_event_state}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/get-novel")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{legacy_id},"page":1,"limit":10}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, get_pg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get_novel={get_pg}");
    assert_eq!(get_pg["total"].as_i64(), Some(1));
    let page_rows = get_pg["data"].as_array().expect("get-novel data");
    assert_eq!(page_rows[0]["id"].as_i64(), Some(i64::from(novel_leg)));

    let add_body = format!(
        r#"{{"projectId":{legacy_id},"data":[{{"index":99,"reel":"lr","chapter":"pg_legacy_add_chapter","chapterData":"d0"}}]}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/add-novel")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(add_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, add_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "add_novel={add_msg}");
    assert_eq!(add_msg["message"].as_str(), Some("新增原文成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/get-novel")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{legacy_id},"page":1,"limit":10}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, two_rows) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "two_rows={two_rows}");
    assert_eq!(two_rows["total"].as_i64(), Some(2));
    let added_leg = two_rows["data"]
        .as_array()
        .expect("data")
        .iter()
        .find(|r| r["chapter"].as_str() == Some("pg_legacy_add_chapter"))
        .expect("added chapter row")["id"]
        .as_i64()
        .expect("added legacy id") as i32;

    let upd = format!(
        r#"{{"id":{added_leg},"index":99,"reel":"","chapter":"pg_legacy_patched","chapterData":"d1","event":""}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/update-novel")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(upd))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, upd_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "update_novel={upd_msg}");
    assert_eq!(upd_msg["message"].as_str(), Some("更新原文成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/get-novel")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{legacy_id},"page":1,"limit":10,"search":"pg_legacy_pat"}}"#
                )))
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
                .method(Method::POST)
                .uri("/api/v1/novels/delete-novel")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":{added_leg}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, del_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "delete_novel={del_msg}");
    assert_eq!(del_msg["message"].as_str(), Some("删除原文成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/get-novel")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{legacy_id},"page":1,"limit":10}}"#
                )))
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
                    "/api/v1/projects/legacy/{legacy_id}/novels/{novel_leg}"
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
                    "/api/v1/projects/legacy/{legacy_id}/novels/{novel_leg}"
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
                    "/api/v1/projects/legacy/{legacy_id}/novels/{novel_leg}"
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
                .uri(format!("/api/v1/projects/legacy/{legacy_id}/stats"))
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
                    "/api/v1/projects/legacy/{legacy_id}/novels/{novel_leg}"
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
                .uri(format!("/api/v1/projects/legacy/{legacy_id}"))
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
                .uri(format!("/api/v1/projects/legacy/{legacy_id}/stats"))
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

    let add_body = format!(
        r#"{{
            "projectType":" short-drama ",
            "name":"  {initial_name}  ",
            "intro":"  legacy intro  ",
            "type":" novel ",
            "artStyle":"  ink  ",
            "directorManual":"  story-manual  ",
            "videoRatio":" 9:16 ",
            "imageModel":" dalle-3 ",
            "videoModel":" runway ",
            "imageQuality":" hd ",
            "mode":"   "
        }}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/project/add-project")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(add_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, added) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "added={added}");
    assert_eq!(added["message"].as_str(), Some("新增项目成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/project/get-project")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, listed) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "listed={listed}");
    let created_row = listed["data"]
        .as_array()
        .and_then(|rows| {
            rows.iter()
                .find(|row| row["name"].as_str() == Some(initial_name.as_str()))
        })
        .cloned()
        .expect("created project row");
    let legacy_id = created_row["legacy_id"].as_i64().expect("legacy_id") as i32;
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

    let edit_body = format!(
        r#"{{
            "id":{legacy_id},
            "name":"  {updated_name}  ",
            "intro":"   ",
            "type":"  fallback-mode  ",
            "artStyle":"   ",
            "directorManual":"  revised-manual  ",
            "videoRatio":" 16:9 ",
            "imageModel":" flux ",
            "videoModel":" kling ",
            "imageQuality":" standard ",
            "projectType":" feature ",
            "mode":" professional "
        }}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/project/edit-project")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(edit_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, edited) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "edited={edited}");
    assert_eq!(edited["message"].as_str(), Some("编辑项目成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/project/get-project")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, relisted) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "relisted={relisted}");
    let edited_row = relisted["data"]
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
                .method(Method::POST)
                .uri("/api/v1/project/delete-project")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":{legacy_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, deleted) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "deleted={deleted}");
    assert_eq!(deleted["message"].as_str(), Some("删除项目成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/project/get-project")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, after_delete) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "after_delete={after_delete}");
    let still_present = after_delete["data"].as_array().is_some_and(|rows| {
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
                .method(Method::POST)
                .uri("/api/v1/project/delete-project")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":{legacy_id}}}"#)))
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

    let _ =
        sqlx::query("DELETE FROM public.app_project WHERE owner_user_id = $1 AND legacy_id = $2")
            .bind(sub)
            .bind(legacy_id)
            .execute(&pool)
            .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn legacy_general_project_update_roundtrip() {
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
    let legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;
    let project_uuid = Uuid::parse_str(created["id"].as_str().expect("project id")).unwrap();

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/general/get-single-project")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":{legacy_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, before_update) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "before_update={before_update}");
    assert_eq!(
        before_update["data"][0]["intro"].as_str(),
        Some("before update")
    );
    assert_eq!(before_update["data"][0]["mode"].as_str(), Some("orig-mode"));
    assert_eq!(
        before_update["data"][0]["art_style"].as_str(),
        Some("orig-style")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/general/update-project")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"id":{legacy_id},"intro":"after update","type":"legacy-mode","artStyle":null,"videoRatio":"1:1","projectType":"series"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, updated) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "updated={updated}");
    assert_eq!(updated["message"].as_str(), Some("修改成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/general/get-single-project")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":{legacy_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, after_update) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "after_update={after_update}");
    assert_eq!(
        after_update["data"][0]["name"].as_str(),
        created["name"].as_str(),
        "legacy general wrapper must preserve untouched fields"
    );
    assert_eq!(
        after_update["data"][0]["intro"].as_str(),
        Some("after update")
    );
    assert_eq!(
        after_update["data"][0]["mode"].as_str(),
        Some("legacy-mode")
    );
    assert!(after_update["data"][0]["art_style"].is_null());
    assert_eq!(after_update["data"][0]["video_ratio"].as_str(), Some("1:1"));
    assert_eq!(
        after_update["data"][0]["project_type"].as_str(),
        Some("series")
    );

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

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn asset_image_file_local_storage_roundtrip() {
    use base64::Engine;
    use serde_json::json;

    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let tmp = tempfile::tempdir().expect("tempdir");
    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let user_dir = tmp.path().join(sub.to_string());
    std::fs::create_dir_all(&user_dir).expect("mkdir user image dir");

    let img_id = Uuid::new_v4();
    let png = base64::engine::general_purpose::STANDARD
        .decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
        .expect("1x1 png");
    std::fs::write(user_dir.join(format!("{img_id}.png")), &png).expect("write png");

    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state_with_local_dir(
        pool.clone(),
        secret.clone(),
        tmp.path().to_path_buf(),
    ));

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

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/legacy/{legacy_id}/assets"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"name":"pg_contract_local_png_asset","type":"role"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, asset_row) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "asset={asset_row}");
    let asset_leg = asset_row["legacy_id"].as_i64().expect("asset legacy_id") as i32;
    let asset_id = Uuid::parse_str(asset_row["id"].as_str().expect("asset id")).unwrap();

    let api_file_path =
        format!("/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}/images/{img_id}/file");
    let meta = json!({"storage": "local", "source": "pg_contract"});
    sqlx::query(
        r#"
        INSERT INTO app_asset_image (id, asset_id, sort_index, file_path, state, metadata)
        VALUES ($1, $2, 0, $3, '已完成', $4)
        "#,
    )
    .bind(img_id)
    .bind(asset_id)
    .bind(&api_file_path)
    .bind(Json(meta))
    .execute(&pool)
    .await
    .expect("insert app_asset_image row");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/legacy/{legacy_id}/assets/{asset_leg}/images/{img_id}/file"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let cache_control = res
        .headers()
        .get(header::CACHE_CONTROL)
        .and_then(|v| v.to_str().ok())
        .map(str::to_string);
    let (status, body, ct) = read_bytes_response(res, 512 * 1024).await;
    assert_eq!(status, StatusCode::OK, "file GET");
    assert_eq!(body, png);
    assert!(
        ct.as_deref()
            .is_some_and(|s| s.to_lowercase().starts_with("image/png")),
        "content-type: {ct:?}"
    );
    assert_eq!(
        cache_control.as_deref(),
        Some("private, max-age=300"),
        "cache-control: {cache_control:?}"
    );

    let res = app
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/projects/legacy/{legacy_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NO_CONTENT);
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_generate_enqueue_four_kinds() {
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

    let gen_body = format!(
        r#"{{"projectId":{legacy_id},"model":"1:pg_ag","resolution":"1024x1024","id":1,"type":"role","name":"pg_ag_gen","prompt":"probe","base64":"QUJDRA=="}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets-generate/generate")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(gen_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "generate body={job}");
    assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_GENERATE_IMAGE));
    assert_eq!(job["status"].as_str(), Some("queued"));
    assert_eq!(job["payload"]["has_base64"].as_bool(), Some(true));
    assert_eq!(
        job["payload"]["image_base64"].as_str(),
        Some("data:image/jpeg;base64,QUJDRA==")
    );

    let pol_body = format!(
        r#"{{"assetsId":1,"projectId":{legacy_id},"type":"role","name":"n","describe":"d"}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets-generate/polish-prompt")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(pol_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "polish body={job}");
    assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_POLISH_PROMPT));
    assert_eq!(job["status"].as_str(), Some("queued"));

    let bat_gen = format!(
        r#"{{"projectId":{legacy_id},"model":"1:x","resolution":"1024x1024","items":[{{"id":1,"type":"role","name":"n","prompt":"p","base64":"data:image/png;base64,AA=="}}]}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets-generate/batch-generate")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(bat_gen))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "batch-generate body={job}");
    assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_GENERATE_BATCH));
    assert_eq!(job["status"].as_str(), Some("queued"));
    assert_eq!(
        job["payload"]["items"][0]["has_base64"].as_bool(),
        Some(true)
    );
    assert_eq!(
        job["payload"]["items"][0]["image_base64"].as_str(),
        Some("data:image/png;base64,AA==")
    );

    let bat_pol = format!(
        r#"{{"projectId":{legacy_id},"items":[{{"assetsId":1,"type":"role","name":"n","describe":"d"}}]}}"#
    );
    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets-generate/batch-polish")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(bat_pol))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "batch-polish body={job}");
    assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_POLISH_BATCH));
    assert_eq!(job["status"].as_str(), Some("queued"));
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_generate_cancel_generate_roundtrip() {
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

    let project_id: Uuid = sqlx::query_scalar(
        r#"SELECT id FROM public.app_project WHERE legacy_id = $1 AND owner_user_id = $2"#,
    )
    .bind(legacy_id)
    .bind(sub)
    .fetch_one(&pool)
    .await
    .expect("project uuid by legacy");

    let asset_id = Uuid::new_v4();
    let asset_legacy_id = 7_000_001_i32;
    let now_ms = chrono::Utc::now().timestamp_millis();
    sqlx::query(
        r#"
        INSERT INTO public.app_asset (id, project_id, legacy_id, name, asset_type, create_time_ms, metadata)
        VALUES ($1, $2, $3, $4, 'role', $5, '{}'::jsonb)
        "#,
    )
    .bind(asset_id)
    .bind(project_id)
    .bind(asset_legacy_id)
    .bind(format!("cancel_probe_asset_{}", Uuid::new_v4()))
    .bind(now_ms)
    .execute(&pool)
    .await
    .expect("insert app_asset");

    let image_id = Uuid::new_v4();
    let legacy_image_id = 7_700_001_i32;
    sqlx::query(
        r#"
        INSERT INTO public.app_asset_image (id, asset_id, sort_index, file_path, state, legacy_image_id, metadata)
        VALUES ($1, $2, 0, $3, '生成中', $4, '{"seed":"cancel_roundtrip"}'::jsonb)
        "#,
    )
    .bind(image_id)
    .bind(asset_id)
    .bind("https://example.com/cancel-probe.png")
    .bind(legacy_image_id)
    .execute(&pool)
    .await
    .expect("insert app_asset_image");

    let single_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job (id, owner_user_id, kind, status, payload)
        VALUES ($1, $2, 'asset.generate.image', 'queued', $3::jsonb)
        "#,
    )
    .bind(single_job_id)
    .bind(sub)
    .bind(
        serde_json::json!({
            "source": "pg_contract.assets_generate.cancel.single",
            "project_legacy_id": legacy_id,
            "asset_legacy_id": asset_legacy_id
        })
        .to_string(),
    )
    .execute(&pool)
    .await
    .expect("insert linked single job");

    let batch_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job (id, owner_user_id, kind, status, payload)
        VALUES ($1, $2, 'asset.generate.batch', 'running', $3::jsonb)
        "#,
    )
    .bind(batch_job_id)
    .bind(sub)
    .bind(
        serde_json::json!({
            "source": "pg_contract.assets_generate.cancel.batch",
            "project_legacy_id": legacy_id,
            "items": [
                { "asset_legacy_id": asset_legacy_id, "name": "probe", "prompt": "probe" }
            ]
        })
        .to_string(),
    )
    .execute(&pool)
    .await
    .expect("insert linked batch job");

    let unrelated_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job (id, owner_user_id, kind, status, payload)
        VALUES ($1, $2, 'asset.generate.image', 'queued', $3::jsonb)
        "#,
    )
    .bind(unrelated_job_id)
    .bind(sub)
    .bind(
        serde_json::json!({
            "source": "pg_contract.assets_generate.cancel.unrelated",
            "project_legacy_id": legacy_id,
            "asset_legacy_id": asset_legacy_id + 999
        })
        .to_string(),
    )
    .execute(&pool)
    .await
    .expect("insert unrelated job");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets-generate/cancel-generate")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":{legacy_image_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "cancel body={body}");
    assert_eq!(body["message"].as_str(), Some("取消成功"));

    let row: Option<(Option<String>, serde_json::Value)> =
        sqlx::query_as(r#"SELECT state, metadata FROM public.app_asset_image WHERE id = $1"#)
            .bind(image_id)
            .fetch_optional(&pool)
            .await
            .expect("read app_asset_image after cancel");
    let (state, metadata) = row.expect("cancelled image row exists");
    assert_eq!(state.as_deref(), Some("生成失败"));
    assert_eq!(metadata["cancelled"].as_bool(), Some(true));
    assert_eq!(
        metadata["cancel_source"].as_str(),
        Some("legacy.assets-generate.cancel-generate")
    );

    let single_after: Option<(String, Option<serde_json::Value>)> = sqlx::query_as(
        r#"SELECT status::text, result FROM public.app_generation_job WHERE id = $1"#,
    )
    .bind(single_job_id)
    .fetch_optional(&pool)
    .await
    .expect("read linked single job");
    let (single_status, single_result) = single_after.expect("linked single job exists");
    assert_eq!(single_status, "cancelled");
    assert_eq!(
        single_result
            .as_ref()
            .and_then(|v| v.get("cancel_source"))
            .and_then(serde_json::Value::as_str),
        Some("legacy.assets-generate.cancel-generate")
    );

    let batch_after: Option<(String, Option<serde_json::Value>)> = sqlx::query_as(
        r#"SELECT status::text, result FROM public.app_generation_job WHERE id = $1"#,
    )
    .bind(batch_job_id)
    .fetch_optional(&pool)
    .await
    .expect("read linked batch job");
    let (batch_status, batch_result) = batch_after.expect("linked batch job exists");
    assert_eq!(batch_status, "cancelled");
    assert_eq!(
        batch_result
            .as_ref()
            .and_then(|v| v.get("cancel_legacy_image_id"))
            .and_then(serde_json::Value::as_i64),
        Some(i64::from(legacy_image_id))
    );

    let unrelated_after: Option<String> =
        sqlx::query_scalar(r#"SELECT status::text FROM public.app_generation_job WHERE id = $1"#)
            .bind(unrelated_job_id)
            .fetch_optional(&pool)
            .await
            .expect("read unrelated job");
    assert_eq!(unrelated_after.as_deref(), Some("queued"));

    let res = app
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/projects/legacy/{legacy_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NO_CONTENT);
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_upload_clip_roundtrip() {
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
    let project_legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

    let clip_name = format!("pg_clip_{}", Uuid::new_v4());
    let body = format!(
        r#"{{"projectId":{project_legacy_id},"name":"{clip_name}","base64Data":"QUJDRA=="}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/upload-clip")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, uploaded) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "uploaded={uploaded}");
    assert_eq!(uploaded["message"].as_str(), Some("上传成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/get-material-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_legacy_id}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, material) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "material={material}");
    let row = material["data"]
        .as_array()
        .expect("material.data")
        .iter()
        .find(|r| r["name"].as_str() == Some(clip_name.as_str()))
        .expect("uploaded clip row");
    assert_eq!(row["type"].as_str(), Some("clip"));
    assert_eq!(
        row["filePath"].as_str(),
        Some("data:application/octet-stream;base64,QUJDRA==")
    );

    let clip_legacy_id = row["id"].as_i64().expect("clip legacy id") as i32;
    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/get-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"assetsId":{clip_legacy_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, image_bundle) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "image_bundle={image_bundle}");
    assert_eq!(
        image_bundle["imageId"].as_i64(),
        image_bundle["tempAssets"][0]["id"].as_i64()
    );
    assert_eq!(
        image_bundle["tempAssets"][0]["selected"].as_bool(),
        Some(true)
    );
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_legacy_mutation_endpoints_roundtrip() {
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
    let (status, created_project) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CREATED,
        "created_project={created_project}"
    );
    let project_legacy_id = created_project["legacy_id"]
        .as_i64()
        .expect("project legacy id") as i32;

    let base_name = format!("pg_legacy_asset_{}", Uuid::new_v4().simple());
    let asset_a_name = format!("{base_name}_a");
    let asset_b_name = format!("{base_name}_b");
    let asset_c_name = format!("{base_name}_c");
    let asset_d_name = format!("{base_name}_d");

    let create_body = format!(
        r#"{{"name":"{asset_a_name}","describe":"desc a","type":"role","projectId":{project_legacy_id},"remark":"  r0  ","prompt":"  p0  "}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/add-assets")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(create_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, add_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "add_msg={add_msg}");
    assert_eq!(add_msg["message"].as_str(), Some("新增资产成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/legacy/{project_legacy_id}/assets?name={asset_a_name}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_a) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list_a={list_a}");
    assert_eq!(list_a["total"].as_i64(), Some(1));
    let asset_a_legacy_id = list_a["items"][0]["legacy_id"]
        .as_i64()
        .expect("asset_a legacy id") as i32;
    assert_eq!(
        list_a["items"][0]["metadata"]["prompt"].as_str(),
        Some("p0"),
        "prompt should be trimmed on add-assets"
    );
    assert_eq!(
        list_a["items"][0]["metadata"]["remark"].as_str(),
        Some("r0"),
        "remark should be trimmed on add-assets"
    );

    let save_body = format!(
        r#"{{"id":{asset_a_legacy_id},"projectId":{project_legacy_id},"type":"role","prompt":"  p1  ","base64":"QUJDRA=="}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/save-assets")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(save_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, save_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "save_msg={save_msg}");
    assert_eq!(save_msg["message"].as_str(), Some("保存资产图片成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/get-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"assetsId":{asset_a_legacy_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, get_image) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get_image={get_image}");
    let image_legacy_id = get_image["imageId"].as_i64().expect("imageId") as i32;
    assert_eq!(
        get_image["tempAssets"]
            .as_array()
            .map(|arr| arr.len())
            .unwrap_or(0),
        1
    );
    assert_eq!(get_image["tempAssets"][0]["selected"].as_bool(), Some(true));

    let update_body = format!(
        r#"{{"id":{asset_a_legacy_id},"name":"{asset_a_name}_u","describe":"desc a2","remark":"  r2  ","prompt":"   "}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/update-assets")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(update_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, update_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "update_msg={update_msg}");
    assert_eq!(update_msg["message"].as_str(), Some("更新资产成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/legacy/{project_legacy_id}/assets/{asset_a_legacy_id}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, asset_after_update) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "asset_after_update={asset_after_update}"
    );
    assert_eq!(
        asset_after_update["name"].as_str(),
        Some(format!("{asset_a_name}_u").as_str())
    );
    assert_eq!(asset_after_update["description"].as_str(), Some("desc a2"));
    assert!(
        asset_after_update["metadata"]["prompt"].is_null(),
        "blank prompt should clear metadata.prompt"
    );
    assert_eq!(
        asset_after_update["metadata"]["remark"].as_str(),
        Some("r2")
    );
    assert_eq!(
        asset_after_update["metadata"]["imageId"].as_i64(),
        Some(i64::from(image_legacy_id))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/del-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":{image_legacy_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, del_image_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "del_image_msg={del_image_msg}");
    assert_eq!(del_image_msg["message"].as_str(), Some("资产图片删除成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/get-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"assetsId":{asset_a_legacy_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, image_after_delete) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "image_after_delete={image_after_delete}"
    );
    assert!(image_after_delete["imageId"].is_null());
    assert!(image_after_delete["tempAssets"]
        .as_array()
        .is_some_and(|arr| arr.is_empty()));

    for name in [&asset_b_name, &asset_c_name, &asset_d_name] {
        let create_body = format!(
            r#"{{"name":"{name}","describe":"desc","type":"role","projectId":{project_legacy_id}}}"#
        );
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/assets/add-assets")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(create_body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, add_msg) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "add_msg={add_msg}");
    }

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/legacy/{project_legacy_id}/assets?name={asset_b_name}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_b) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list_b={list_b}");
    let asset_b_legacy_id = list_b["items"][0]["legacy_id"]
        .as_i64()
        .expect("asset_b legacy id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/del-assets")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":{asset_b_legacy_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, del_asset_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "del_asset_msg={del_asset_msg}");
    assert_eq!(del_asset_msg["message"].as_str(), Some("删除资产成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/legacy/{project_legacy_id}/assets?name={asset_c_name}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_c) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list_c={list_c}");
    assert_eq!(list_c["total"].as_i64(), Some(1), "list_c={list_c}");
    let asset_c_legacy_id = list_c["items"][0]["legacy_id"]
        .as_i64()
        .expect("asset_c legacy id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/legacy/{project_legacy_id}/assets?name={asset_d_name}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_d) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list_d={list_d}");
    assert_eq!(list_d["total"].as_i64(), Some(1), "list_d={list_d}");
    let asset_d_legacy_id = list_d["items"][0]["legacy_id"]
        .as_i64()
        .expect("asset_d legacy id") as i32;

    let batch_delete_body = format!(r#"{{"id":[{asset_c_legacy_id},{asset_d_legacy_id}]}}"#);
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/batch-delete")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(batch_delete_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, batch_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "batch_msg={batch_msg}");
    assert_eq!(batch_msg["message"].as_str(), Some("删除资产成功"));

    for name in [&asset_b_name, &asset_c_name, &asset_d_name] {
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/legacy/{project_legacy_id}/assets?name={name}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, list_after_delete) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "list_after_delete={list_after_delete}"
        );
        assert_eq!(list_after_delete["total"].as_i64(), Some(0));
    }
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_get_assets_api_parent_child_roundtrip() {
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
    let (status, created_project) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CREATED,
        "created_project={created_project}"
    );
    let project_legacy_id = created_project["legacy_id"]
        .as_i64()
        .expect("project legacy id") as i32;

    let parent_a_name = format!("pg_parent_a_{}", Uuid::new_v4());
    let parent_b_name = format!("pg_parent_b_{}", Uuid::new_v4());
    let child_a_name = format!("pg_child_a_{}", Uuid::new_v4());
    let child_b_name = format!("pg_child_b_{}", Uuid::new_v4());

    let (status, parent_a) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{project_legacy_id}/assets"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{parent_a_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "parent_a={parent_a}");
    let parent_a_legacy_id = parent_a["legacy_id"].as_i64().expect("parent_a legacy id") as i32;

    let (status, parent_b) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{project_legacy_id}/assets"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{parent_b_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "parent_b={parent_b}");
    let parent_b_legacy_id = parent_b["legacy_id"].as_i64().expect("parent_b legacy id") as i32;

    let (status, child_a) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{project_legacy_id}/assets"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{child_a_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "child_a={child_a}");
    let child_a_legacy_id = child_a["legacy_id"].as_i64().expect("child_a legacy id") as i32;

    let (status, child_b) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{project_legacy_id}/assets"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{child_b_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "child_b={child_b}");
    let child_b_legacy_id = child_b["legacy_id"].as_i64().expect("child_b legacy id") as i32;

    let parent_a_uuid: Uuid = sqlx::query_scalar(
        r#"SELECT id
           FROM app_asset
           WHERE project_id = (SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $2)
             AND legacy_id = $3"#,
    )
    .bind(project_legacy_id)
    .bind(sub)
    .bind(parent_a_legacy_id)
    .fetch_one(&pool)
    .await
    .expect("parent_a uuid");

    sqlx::query(
        r#"
        UPDATE app_asset
        SET metadata = jsonb_set(
          jsonb_set(COALESCE(metadata, '{}'::jsonb), '{projectId}', to_jsonb($1::integer), true),
          '{assetsId}',
          to_jsonb($2::integer),
          true
        )
        WHERE project_id = (SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $3)
          AND legacy_id = $4
        "#,
    )
    .bind(project_legacy_id)
    .bind(parent_a_legacy_id)
    .bind(sub)
    .bind(child_a_legacy_id)
    .execute(&pool)
    .await
    .expect("child_a metadata.assetsId");

    sqlx::query(
        r#"
        UPDATE app_asset
        SET metadata = jsonb_set(
          jsonb_set(COALESCE(metadata, '{}'::jsonb), '{projectId}', to_jsonb($1::integer), true),
          '{assetsId}',
          to_jsonb($2::integer),
          true
        )
        WHERE project_id = (SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $3)
          AND legacy_id = $4
        "#,
    )
    .bind(project_legacy_id)
    .bind(parent_b_legacy_id)
    .bind(sub)
    .bind(child_b_legacy_id)
    .execute(&pool)
    .await
    .expect("child_b metadata.assetsId");

    let parent_a_image_legacy_id = 9_901_001;
    sqlx::query(
        r#"
        UPDATE app_asset
        SET metadata = jsonb_set(
          jsonb_set(COALESCE(metadata, '{}'::jsonb), '{projectId}', to_jsonb($1::integer), true),
          '{imageId}',
          to_jsonb($2::integer),
          true
        )
        WHERE project_id = (SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $3)
          AND legacy_id = $4
        "#,
    )
    .bind(project_legacy_id)
    .bind(parent_a_image_legacy_id)
    .bind(sub)
    .bind(parent_a_legacy_id)
    .execute(&pool)
    .await
    .expect("parent_a metadata.imageId");

    sqlx::query(
        r#"
        INSERT INTO app_asset_image (asset_id, sort_index, file_path, state, legacy_image_id, metadata)
        VALUES ($1, 0, '/tmp/pg_parent_a_selected.png', '失败', $2, '{"errorReason":"provider_timeout"}'::jsonb)
        "#,
    )
    .bind(parent_a_uuid)
    .bind(parent_a_image_legacy_id)
    .execute(&pool)
    .await
    .expect("insert parent_a selected image");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/get-assets-api")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_legacy_id},"type":"role","page":1,"limit":1}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, first_page) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "first_page={first_page}");
    assert_eq!(first_page["total"].as_i64(), Some(2));
    let rows = first_page["data"].as_array().expect("first page data");
    assert_eq!(rows.len(), 1);
    let first_parent = &rows[0];
    assert_eq!(
        first_parent["id"].as_i64(),
        Some(i64::from(parent_a_legacy_id))
    );
    assert_eq!(
        first_parent["filePath"].as_str(),
        Some("/tmp/pg_parent_a_selected.png")
    );
    assert_eq!(
        first_parent["src"].as_str(),
        Some("/tmp/pg_parent_a_selected.png")
    );
    assert_eq!(first_parent["state"].as_str(), Some("失败"));
    assert_eq!(
        first_parent["errorReason"].as_str(),
        Some("provider_timeout")
    );
    let first_children = first_parent["sonAssets"]
        .as_array()
        .expect("first parent sonAssets");
    assert_eq!(first_children.len(), 1);
    assert_eq!(
        first_children[0]["id"].as_i64(),
        Some(i64::from(child_a_legacy_id))
    );
    assert_eq!(
        first_children[0]["assetsId"].as_i64(),
        Some(i64::from(parent_a_legacy_id))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/get-assets-api")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_legacy_id},"type":"role","page":2,"limit":1}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, second_page) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "second_page={second_page}");
    assert_eq!(second_page["total"].as_i64(), Some(2));
    let rows = second_page["data"].as_array().expect("second page data");
    assert_eq!(rows.len(), 1);
    let second_parent = &rows[0];
    assert_eq!(
        second_parent["id"].as_i64(),
        Some(i64::from(parent_b_legacy_id))
    );
    let second_children = second_parent["sonAssets"]
        .as_array()
        .expect("second parent sonAssets");
    assert_eq!(second_children.len(), 1);
    assert_eq!(
        second_children[0]["id"].as_i64(),
        Some(i64::from(child_b_legacy_id))
    );
    assert_eq!(
        second_children[0]["assetsId"].as_i64(),
        Some(i64::from(parent_b_legacy_id))
    );
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_polling_image_and_prompt_filters_roundtrip() {
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
    let (status, created_project) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CREATED,
        "created_project={created_project}"
    );
    let project_legacy_id = created_project["legacy_id"]
        .as_i64()
        .expect("project legacy id") as i32;

    let ready_asset_name = format!("pg_polling_ready_{}", Uuid::new_v4());
    let running_asset_name = format!("pg_polling_running_{}", Uuid::new_v4());

    let (status, ready_asset) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{project_legacy_id}/assets"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{ready_asset_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "ready_asset={ready_asset}");
    let ready_asset_legacy_id = ready_asset["legacy_id"]
        .as_i64()
        .expect("ready asset legacy id") as i32;

    let (status, running_asset) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/legacy/{project_legacy_id}/assets"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{running_asset_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "running_asset={running_asset}");
    let running_asset_legacy_id = running_asset["legacy_id"]
        .as_i64()
        .expect("running asset legacy id") as i32;

    let ready_asset_uuid: Uuid = sqlx::query_scalar(
        r#"SELECT id
           FROM app_asset
           WHERE project_id = (SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $2)
             AND legacy_id = $3"#,
    )
    .bind(project_legacy_id)
    .bind(sub)
    .bind(ready_asset_legacy_id)
    .fetch_one(&pool)
    .await
    .expect("ready asset uuid");
    let running_asset_uuid: Uuid = sqlx::query_scalar(
        r#"SELECT id
           FROM app_asset
           WHERE project_id = (SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $2)
             AND legacy_id = $3"#,
    )
    .bind(project_legacy_id)
    .bind(sub)
    .bind(running_asset_legacy_id)
    .fetch_one(&pool)
    .await
    .expect("running asset uuid");

    let ready_image_legacy_id = 9_902_001;
    let running_image_legacy_id = 9_902_002;

    sqlx::query(
        r#"
        UPDATE app_asset
        SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{imageId}', to_jsonb($1::integer), true)
        WHERE id = $2
        "#,
    )
    .bind(ready_image_legacy_id)
    .bind(ready_asset_uuid)
    .execute(&pool)
    .await
    .expect("set ready imageId");

    sqlx::query(
        r#"
        UPDATE app_asset
        SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{imageId}', to_jsonb($1::integer), true)
        WHERE id = $2
        "#,
    )
    .bind(running_image_legacy_id)
    .bind(running_asset_uuid)
    .execute(&pool)
    .await
    .expect("set running imageId");

    sqlx::query(
        r#"
        INSERT INTO app_asset_image (asset_id, sort_index, file_path, state, legacy_image_id)
        VALUES
          ($1, 0, '/tmp/pg_polling_ready.png', '已完成', $2),
          ($3, 0, '/tmp/pg_polling_running.png', '生成中', $4)
        "#,
    )
    .bind(ready_asset_uuid)
    .bind(ready_image_legacy_id)
    .bind(running_asset_uuid)
    .bind(running_image_legacy_id)
    .execute(&pool)
    .await
    .expect("insert selected images");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/polling-image-assets")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"ids":[{ready_asset_legacy_id},{running_asset_legacy_id}]}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, polling_image) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "polling_image={polling_image}");
    let rows = polling_image.as_array().expect("polling image rows");
    assert_eq!(rows.len(), 1);
    assert_eq!(
        rows[0]["id"].as_i64(),
        Some(i64::from(ready_asset_legacy_id))
    );
    assert_eq!(
        rows[0]["filePath"].as_str(),
        Some("/tmp/pg_polling_ready.png")
    );
    assert_eq!(rows[0]["state"].as_str(), Some("已完成"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .header(
                    "Idempotency-Key",
                    format!("polling-ready-{}", Uuid::new_v4()),
                )
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"kind":"{JOB_KIND_ASSET_POLISH_PROMPT}","payload":{{"asset_legacy_id":{ready_asset_legacy_id}}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, ready_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "ready_job={ready_job}");
    let ready_job_id = ready_job["id"].as_str().expect("ready job id");
    sqlx::query(r#"UPDATE app_generation_job SET status = 'failed' WHERE id = $1::uuid"#)
        .bind(ready_job_id)
        .execute(&pool)
        .await
        .expect("mark ready job failed");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .header(
                    "Idempotency-Key",
                    format!("polling-running-{}", Uuid::new_v4()),
                )
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"kind":"{JOB_KIND_ASSET_POLISH_PROMPT}","payload":{{"asset_legacy_id":{running_asset_legacy_id}}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, running_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "running_job={running_job}");
    assert_eq!(running_job["status"].as_str(), Some("queued"));

    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/polling-prompt-assets")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"ids":[{ready_asset_legacy_id},{running_asset_legacy_id}]}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, polling_prompt) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "polling_prompt={polling_prompt}");
    let rows = polling_prompt.as_array().expect("polling prompt rows");
    assert_eq!(rows.len(), 1);
    assert_eq!(
        rows[0]["id"].as_i64(),
        Some(i64::from(ready_asset_legacy_id))
    );
    assert_eq!(rows[0]["promptState"].as_str(), Some("失败"));
    assert_eq!(rows[0]["name"].as_str(), Some(ready_asset_name.as_str()));
    assert_eq!(rows[0]["type"].as_str(), Some("role"));
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_batch_generation_data_filters_roundtrip() {
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
    let (status, created_project) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CREATED,
        "created_project={created_project}"
    );
    let project_legacy_id = created_project["legacy_id"]
        .as_i64()
        .expect("project legacy id") as i32;

    let make_asset = |name: &str, kind: &str| -> Request<Body> {
        Request::builder()
            .method(Method::POST)
            .uri(format!(
                "/api/v1/projects/legacy/{project_legacy_id}/assets"
            ))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(format!(
                r#"{{"name":"{name}","type":"{kind}"}}"#
            )))
            .unwrap()
    };

    let role_name_a = format!("pg_batch_role_a_{}", Uuid::new_v4());
    let role_name_b = format!("pg_batch_role_b_{}", Uuid::new_v4());
    let scene_name = format!("pg_batch_scene_{}", Uuid::new_v4());

    let (status, _) = read_json_response(
        app.clone()
            .oneshot(make_asset(&role_name_a, "role"))
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "create role a");
    let (status, _) = read_json_response(
        app.clone()
            .oneshot(make_asset(&role_name_b, "role"))
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "create role b");
    let (status, _) = read_json_response(
        app.clone()
            .oneshot(make_asset(&scene_name, "scene"))
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "create scene");

    let filter_body = format!(
        r#"{{"projectId":{project_legacy_id},"type":"role","name":"role_","page":1,"limit":1}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/batch-generation-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(filter_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, page_1) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "page_1={page_1}");
    assert_eq!(page_1["total"].as_i64(), Some(2));
    assert_eq!(page_1["data"].as_array().expect("page_1.data").len(), 1);
    let first_name = page_1["data"][0]["name"]
        .as_str()
        .expect("page_1 first name")
        .to_string();
    assert!(first_name == role_name_a || first_name == role_name_b);
    assert_eq!(page_1["data"][0]["type"].as_str(), Some("role"));

    let filter_body_page_2 = format!(
        r#"{{"projectId":{project_legacy_id},"type":"role","name":"role_","page":2,"limit":1}}"#
    );
    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets/batch-generation-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(filter_body_page_2))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, page_2) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "page_2={page_2}");
    assert_eq!(page_2["total"].as_i64(), Some(2));
    assert_eq!(page_2["data"].as_array().expect("page_2.data").len(), 1);
    let second_name = page_2["data"][0]["name"]
        .as_str()
        .expect("page_2 first name");
    assert!(second_name == role_name_a || second_name == role_name_b);
    assert_ne!(first_name, second_name);
    assert_eq!(page_2["data"][0]["type"].as_str(), Some("role"));
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn settings_vendor_model_test_enqueue() {
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
    let app = build_router(contract_state(pool, secret));

    let body = r#"{"modelName":"pg_vendor_mt","type":"text","id":"probe-id"}"#;
    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/model-test")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "model-test body={job}");
    assert_eq!(
        job["kind"].as_str(),
        Some(JOB_KIND_SETTINGS_VENDOR_MODEL_TEST)
    );
    assert_eq!(job["status"].as_str(), Some("queued"));
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn quality_reviews_roundtrip() {
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

    let quality_job_id = Uuid::new_v4();
    let script_target_id = format!("pg_quality_script_{}", Uuid::new_v4());
    let asset_target_id = format!("pg_quality_asset_{}", Uuid::new_v4());
    let mut created_review_ids = Vec::new();
    let mut created_job_ids = Vec::new();
    let script_review_id_text;
    let asset_review_id_text;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .header("Idempotency-Key", format!("quality-review-{quality_job_id}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"kind":"flutter.probe","payload":{{"scope":"quality-review","marker":"{quality_job_id}"}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "created_job={created_job}");
    let quality_job_id = Uuid::parse_str(created_job["id"].as_str().expect("quality job id"))
        .expect("quality job uuid");
    created_job_ids.push(quality_job_id);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/quality/reviews")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"targetType":"script","targetId":"{script_target_id}","jobId":"{quality_job_id}","source":"auto","overallScore":8,"passed":true,"comments":"pg quality script"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created_script) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "script review={created_script}");
    assert_eq!(created_script["targetType"], "script");
    assert_eq!(
        created_script["targetId"].as_str(),
        Some(script_target_id.as_str())
    );
    assert_eq!(created_script["source"], "auto");
    assert_eq!(created_script["overallScore"], 8);
    assert_eq!(created_script["passed"], true);
    let script_review_id =
        Uuid::parse_str(created_script["id"].as_str().expect("script review id")).unwrap();
    script_review_id_text = script_review_id.to_string();
    created_review_ids.push(script_review_id);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/quality/reviews")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"targetType":"asset","targetId":"{asset_target_id}","jobId":"{quality_job_id}","overallScore":4,"passed":false,"isBadCase":true,"badCaseCategory":"visual_error","comments":"pg quality asset"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created_asset) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "asset review={created_asset}");
    assert_eq!(created_asset["targetType"], "asset");
    assert_eq!(
        created_asset["targetId"].as_str(),
        Some(asset_target_id.as_str())
    );
    assert_eq!(created_asset["source"], "manual");
    assert_eq!(created_asset["isBadCase"], true);
    assert_eq!(created_asset["badCaseCategory"], "visual_error");
    let asset_review_id =
        Uuid::parse_str(created_asset["id"].as_str().expect("asset review id")).unwrap();
    asset_review_id_text = asset_review_id.to_string();
    created_review_ids.push(asset_review_id);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/quality/reviews?targetType=script&targetId={script_target_id}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, filtered) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "filtered={filtered}");
    let filtered = filtered.as_array().expect("filtered list");
    assert_eq!(filtered.len(), 1);
    assert_eq!(
        filtered[0]["id"].as_str(),
        Some(script_review_id_text.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/quality/reviews?isBadCase=true")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, bad_cases) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "bad_cases={bad_cases}");
    let bad_cases = bad_cases.as_array().expect("bad cases list");
    assert!(
        bad_cases
            .iter()
            .any(|row| row["id"].as_str() == Some(asset_review_id_text.as_str())),
        "bad case list should include created asset review: {bad_cases:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/quality/reviews?jobId={quality_job_id}&limit=1&offset=0"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job_page_one) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "job_page_one={job_page_one}");
    let job_page_one = job_page_one.as_array().expect("job page one");
    assert_eq!(job_page_one.len(), 1);
    assert_eq!(
        job_page_one[0]["id"].as_str(),
        Some(asset_review_id_text.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/quality/reviews?jobId={quality_job_id}&limit=1&offset=1"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job_page_two) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "job_page_two={job_page_two}");
    let job_page_two = job_page_two.as_array().expect("job page two");
    assert_eq!(job_page_two.len(), 1);
    assert_eq!(
        job_page_two[0]["id"].as_str(),
        Some(script_review_id_text.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/quality/reviews?jobId={quality_job_id}&targetType=asset&isBadCase=true"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, combined_filters) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "combined_filters={combined_filters}"
    );
    let combined_filters = combined_filters.as_array().expect("combined filter rows");
    assert_eq!(combined_filters.len(), 1);
    assert_eq!(
        combined_filters[0]["id"].as_str(),
        Some(asset_review_id_text.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/quality/reviews?targetId={script_target_id}&limit=1&offset=0"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, target_id_only) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "target_id_only={target_id_only}");
    let target_id_only = target_id_only.as_array().expect("target id only rows");
    assert_eq!(target_id_only.len(), 1);
    assert_eq!(
        target_id_only[0]["id"].as_str(),
        Some(script_review_id_text.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/quality/reviews/{script_review_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, review_by_id) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "review_by_id={review_by_id}");
    assert_eq!(
        review_by_id["targetId"].as_str(),
        Some(script_target_id.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/quality/stats")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, stats) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "stats={stats}");
    let stats = stats.as_array().expect("stats list");
    let script_stats = stats
        .iter()
        .find(|row| row["targetType"].as_str() == Some("script"))
        .expect("script stats row");
    assert!(
        script_stats["totalReviews"].as_i64().unwrap_or_default() >= 1,
        "script stats={script_stats}"
    );
    assert!(
        script_stats["passedCount"].as_i64().unwrap_or_default() >= 1,
        "script stats={script_stats}"
    );
    let asset_stats = stats
        .iter()
        .find(|row| row["targetType"].as_str() == Some("asset"))
        .expect("asset stats row");
    assert!(
        asset_stats["badCaseCount"].as_i64().unwrap_or_default() >= 1,
        "asset stats={asset_stats}"
    );
    assert!(
        asset_stats["failedCount"].as_i64().unwrap_or_default() >= 1,
        "asset stats={asset_stats}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/quality/stage-pass-rate")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, stage_rows) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "stage_rows={stage_rows}");
    let stage_rows = stage_rows.as_array().expect("stage pass rate list");
    assert!(
        stage_rows.iter().any(|row| {
            row["targetType"].as_str() == Some("script")
                && row["passedCount"].as_i64().unwrap_or_default() >= 1
        }),
        "stage rows should include script aggregate: {stage_rows:?}"
    );
    assert!(
        stage_rows.iter().any(|row| {
            row["targetType"].as_str() == Some("asset")
                && row["badCaseCount"].as_i64().unwrap_or_default() >= 1
        }),
        "stage rows should include asset aggregate: {stage_rows:?}"
    );

    cleanup_quality_reviews(&pool, &created_review_ids).await;
    cleanup_jobs(&pool, &created_job_ids).await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn tasks_legacy_roundtrip() {
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

    let project_name = format!("pg_task_center_{}", Uuid::new_v4());
    let idem_key = format!("pg-task-idem-{}", Uuid::new_v4());
    let mut created_job_ids = Vec::new();

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"name":"{project_name}"}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created_project) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "project={created_project}");
    let legacy_project_id = created_project["legacy_id"]
        .as_i64()
        .expect("legacy project id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .header("Idempotency-Key", idem_key.as_str())
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"kind":"flutter.probe","payload":{{"project_legacy_id":"{legacy_project_id}","scope":"task-center","marker":"idem"}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "created_job={created_job}");
    let created_job_id =
        Uuid::parse_str(created_job["id"].as_str().expect("created job id")).unwrap();
    created_job_ids.push(created_job_id);
    assert_eq!(
        created_job["idempotency_key"].as_str(),
        Some(idem_key.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .header("Idempotency-Key", idem_key.as_str())
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"kind":"flutter.probe","payload":{{"project_legacy_id":"{legacy_project_id}","scope":"task-center","marker":"idem-retry"}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, idem_retry) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "idem_retry={idem_retry}");
    assert_eq!(idem_retry["id"], created_job["id"]);
    assert_eq!(idem_retry["payload"]["marker"], "idem");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"kind":"{JOB_KIND_ASSET_GENERATE_IMAGE}","payload":{{"project_legacy_id":"{legacy_project_id}","scope":"task-center","marker":"failed"}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, failed_seed_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "failed_seed_job={failed_seed_job}");
    let failed_seed_job_id =
        Uuid::parse_str(failed_seed_job["id"].as_str().expect("failed seed job id")).unwrap();
    created_job_ids.push(failed_seed_job_id);

    sqlx::query(
        "UPDATE public.app_generation_job SET status = 'failed', error_message = 'pg task center failure' WHERE id = $1",
    )
    .bind(failed_seed_job_id)
    .execute(&pool)
    .await
    .expect("mark failed seed job");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/tasks/get-project")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, task_projects) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "task_projects={task_projects}");
    let task_projects = task_projects["data"].as_array().expect("task project rows");
    assert!(
        task_projects.iter().any(|row| {
            row["id"].as_i64() == Some(i64::from(legacy_project_id))
                && row["name"].as_str() == Some(project_name.as_str())
        }),
        "task center project list should include created project: {task_projects:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/tasks/get-task-categories")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, task_categories) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "task_categories={task_categories}");
    let task_categories = task_categories["data"]
        .as_array()
        .expect("task category rows");
    assert!(
        task_categories
            .iter()
            .any(|row| row["taskClass"].as_str() == Some("flutter.probe")),
        "task categories should include flutter.probe: {task_categories:?}"
    );
    assert!(
        task_categories
            .iter()
            .any(|row| row["taskClass"].as_str() == Some(JOB_KIND_ASSET_GENERATE_IMAGE)),
        "task categories should include asset generate: {task_categories:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/tasks/get-task-api")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"page":1,"limit":10,"projectId":{legacy_project_id},"taskClass":"flutter.probe","state":"queued"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, filtered_jobs) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "filtered_jobs={filtered_jobs}");
    assert_eq!(filtered_jobs["total"].as_i64(), Some(1));
    let filtered_jobs = filtered_jobs["data"]
        .as_array()
        .expect("filtered task rows");
    assert_eq!(filtered_jobs.len(), 1);
    assert_eq!(filtered_jobs[0]["id"], created_job["id"]);
    assert_eq!(filtered_jobs[0]["status"], "queued");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/tasks/get-task-api")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"page":1,"limit":10,"projectId":0,"taskClass":"flutter.probe","state":"queued"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, zero_project_filter_jobs) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "zero_project_filter_jobs={zero_project_filter_jobs}"
    );
    assert_eq!(zero_project_filter_jobs["total"].as_i64(), Some(1));
    let zero_project_filter_jobs = zero_project_filter_jobs["data"]
        .as_array()
        .expect("zero project filter task rows");
    assert_eq!(zero_project_filter_jobs.len(), 1);
    assert_eq!(zero_project_filter_jobs[0]["id"], created_job["id"]);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/tasks/get-task-api")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"page":1,"limit":10,"projectId":{legacy_project_id},"state":"failed"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, failed_jobs) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "failed_jobs={failed_jobs}");
    assert_eq!(failed_jobs["total"].as_i64(), Some(1));
    let failed_jobs = failed_jobs["data"].as_array().expect("failed task rows");
    assert_eq!(failed_jobs.len(), 1);
    assert_eq!(failed_jobs[0]["id"], failed_seed_job["id"]);
    assert_eq!(failed_jobs[0]["status"], "failed");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/tasks/task-details")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"taskId":"{created_job_id}"}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, task_detail) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "task_detail={task_detail}");
    assert_eq!(task_detail["id"], created_job["id"]);
    assert_eq!(task_detail["legacy_task_id"], created_job["legacy_task_id"]);
    let legacy_project_id_text = legacy_project_id.to_string();
    assert_eq!(
        task_detail["payload"]["project_legacy_id"].as_str(),
        Some(legacy_project_id_text.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/tasks/task-details")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"taskId":{}}}"#,
                    created_job["legacy_task_id"]
                        .as_i64()
                        .expect("legacy task id")
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, task_detail_by_int) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "task_detail_by_int={task_detail_by_int}"
    );
    assert_eq!(task_detail_by_int["id"], created_job["id"]);
    assert_eq!(
        task_detail_by_int["legacy_task_id"],
        created_job["legacy_task_id"]
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/tasks/task-details")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"taskId":"{}"}}"#,
                    created_job["legacy_task_id"]
                        .as_i64()
                        .expect("legacy task id")
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, task_detail_by_numeric_string) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "task_detail_by_numeric_string={task_detail_by_numeric_string}"
    );
    assert_eq!(task_detail_by_numeric_string["id"], created_job["id"]);

    cleanup_jobs(&pool, &created_job_ids).await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(legacy_project_id)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn jobs_rest_roundtrip() {
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

    let mut created_job_ids = Vec::new();
    let cancel_job_id_text;
    let retry_job_id_text;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"kind":"flutter.probe","payload":{"probe":"jobs-rest","slot":"cancel"}}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cancel_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "cancel_job={cancel_job}");
    let cancel_job_id = Uuid::parse_str(cancel_job["id"].as_str().expect("cancel job id")).unwrap();
    cancel_job_id_text = cancel_job_id.to_string();
    created_job_ids.push(cancel_job_id);
    assert_eq!(cancel_job["kind"], "flutter.probe");
    assert_eq!(cancel_job["status"], "queued");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"kind":"{JOB_KIND_ASSET_POLISH_PROMPT}","payload":{{"probe":"jobs-rest","slot":"retry"}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, retry_job_seed) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "retry_job_seed={retry_job_seed}");
    let retry_job_id =
        Uuid::parse_str(retry_job_seed["id"].as_str().expect("retry job id")).unwrap();
    retry_job_id_text = retry_job_id.to_string();
    created_job_ids.push(retry_job_id);
    assert_eq!(retry_job_seed["kind"], JOB_KIND_ASSET_POLISH_PROMPT);
    assert_eq!(retry_job_seed["status"], "queued");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, jobs_before_cancel) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "jobs_before_cancel={jobs_before_cancel}"
    );
    let jobs_before_cancel = jobs_before_cancel.as_array().expect("jobs list");
    assert!(
        jobs_before_cancel
            .iter()
            .any(|row| row["id"].as_str() == Some(cancel_job_id_text.as_str())),
        "jobs list should include cancel job: {jobs_before_cancel:?}"
    );
    assert!(
        jobs_before_cancel
            .iter()
            .any(|row| row["id"].as_str() == Some(retry_job_id_text.as_str())),
        "jobs list should include retry job: {jobs_before_cancel:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/jobs?kind=flutter.probe&status=queued")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, filtered_queued) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "filtered_queued={filtered_queued}");
    let filtered_queued = filtered_queued.as_array().expect("filtered queued rows");
    assert!(
        filtered_queued
            .iter()
            .any(|row| row["id"].as_str() == Some(cancel_job_id_text.as_str())),
        "queued flutter jobs should include cancel target: {filtered_queued:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/jobs/kinds")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, kinds) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "kinds={kinds}");
    let kinds = kinds.as_array().expect("job kinds");
    assert!(
        kinds
            .iter()
            .any(|row| row.as_str() == Some("flutter.probe")),
        "job kinds should include flutter.probe: {kinds:?}"
    );
    assert!(
        kinds
            .iter()
            .any(|row| row.as_str() == Some(JOB_KIND_ASSET_POLISH_PROMPT)),
        "job kinds should include asset polish: {kinds:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/jobs/kinds/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, kind_summary) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "kind_summary={kind_summary}");
    let kind_summary = kind_summary.as_array().expect("job kind summaries");
    assert!(
        kind_summary.iter().any(|row| {
            row["kind"].as_str() == Some("flutter.probe")
                && row["job_count"].as_i64().unwrap_or_default() >= 1
        }),
        "kind summary should include flutter.probe: {kind_summary:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/jobs/status/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, status_summary_before_cancel) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "status_summary_before_cancel={status_summary_before_cancel}"
    );
    let status_summary_before_cancel = status_summary_before_cancel
        .as_array()
        .expect("job status summaries");
    assert!(
        status_summary_before_cancel.iter().any(|row| {
            row["status"].as_str() == Some("queued")
                && row["job_count"].as_i64().unwrap_or_default() >= 2
        }),
        "status summary should include queued jobs: {status_summary_before_cancel:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/jobs/{cancel_job_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, fetched_cancel_job) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "fetched_cancel_job={fetched_cancel_job}"
    );
    assert_eq!(fetched_cancel_job["id"], cancel_job["id"]);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/jobs/{cancel_job_id}/cancel"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cancelled_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "cancelled_job={cancelled_job}");
    assert_eq!(cancelled_job["status"], "cancelled");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/jobs?status=cancelled")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cancelled_list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "cancelled_list={cancelled_list}");
    let cancelled_list = cancelled_list.as_array().expect("cancelled job rows");
    assert!(
        cancelled_list
            .iter()
            .any(|row| row["id"].as_str() == Some(cancel_job_id_text.as_str())),
        "cancelled filter should include cancelled job: {cancelled_list:?}"
    );

    sqlx::query(
        "UPDATE public.app_generation_job SET status = 'failed', error_message = 'pg jobs retry failure', result = '{\"ok\":false}'::jsonb WHERE id = $1",
    )
    .bind(retry_job_id)
    .execute(&pool)
    .await
    .expect("mark retry seed failed");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/jobs/{retry_job_id}/retry"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, retried_job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "retried_job={retried_job}");
    assert_eq!(retried_job["status"], "queued");
    assert!(retried_job["error_message"].is_null());
    assert!(retried_job["result"].is_null());

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/usage/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, usage_summary) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "usage_summary={usage_summary}");
    assert!(
        usage_summary["eventsLast24h"].as_i64().unwrap_or_default() >= 2,
        "usage summary should see created job events: {usage_summary}"
    );
    assert!(
        usage_summary["eventCountsLast7d"]["generation_job.created"]
            .as_i64()
            .unwrap_or_default()
            >= 2,
        "usage summary should include generation_job.created count: {usage_summary}"
    );

    cleanup_jobs(&pool, &created_job_ids).await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn billing_webhook_events_roundtrip() {
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

    let base = Uuid::new_v4().simple().to_string();
    let stripe_info_id = format!("stripe:evt_pg_{base}_info");
    let stripe_failed_id = format!("stripe:evt_pg_{base}_failed");
    let alipay_info_id = format!("alipay:evt_pg_{base}_ali");
    let stripe_info_raw_id = format!("evt_pg_{base}_info");
    let stripe_failed_raw_id = format!("evt_pg_{base}_failed");
    let alipay_raw_id = format!("evt_pg_{base}_ali");
    let created_ids = vec![
        stripe_info_id.clone(),
        stripe_failed_id.clone(),
        alipay_info_id.clone(),
    ];

    cleanup_billing_webhook_events(&pool, &created_ids).await;

    let stripe_info_created = chrono::DateTime::parse_from_rfc3339("2026-04-08T12:00:00Z")
        .unwrap()
        .with_timezone(&chrono::Utc);
    let stripe_failed_created = chrono::DateTime::parse_from_rfc3339("2026-04-08T12:10:00Z")
        .unwrap()
        .with_timezone(&chrono::Utc);
    let alipay_created = chrono::DateTime::parse_from_rfc3339("2026-04-08T12:20:00Z")
        .unwrap()
        .with_timezone(&chrono::Utc);

    let stripe_info_row: (i64,) = sqlx::query_as(
        r#"
        INSERT INTO public.app_billing_webhook_event (
            provider_event_id,
            payload,
            created_at,
            provider,
            raw_event_id,
            event_type,
            event_created_at,
            is_informational_event
        ) VALUES ($1, '{}'::jsonb, $2, 'stripe', $3, 'invoice.upcoming', $4, true)
        RETURNING id
        "#,
    )
    .bind(&stripe_info_id)
    .bind(stripe_info_created)
    .bind(&stripe_info_raw_id)
    .bind(stripe_info_created)
    .fetch_one(&pool)
    .await
    .expect("insert stripe informational webhook row");

    let stripe_failed_row: (i64,) = sqlx::query_as(
        r#"
        INSERT INTO public.app_billing_webhook_event (
            provider_event_id,
            payload,
            created_at,
            provider,
            raw_event_id,
            event_type,
            event_created_at,
            is_informational_event
        ) VALUES ($1, '{}'::jsonb, $2, 'stripe', $3, 'invoice.payment_failed', $4, false)
        RETURNING id
        "#,
    )
    .bind(&stripe_failed_id)
    .bind(stripe_failed_created)
    .bind(&stripe_failed_raw_id)
    .bind(stripe_failed_created)
    .fetch_one(&pool)
    .await
    .expect("insert stripe failed webhook row");

    let _: (i64,) = sqlx::query_as(
        r#"
        INSERT INTO public.app_billing_webhook_event (
            provider_event_id,
            payload,
            created_at,
            provider,
            raw_event_id,
            event_type,
            event_created_at,
            is_informational_event
        ) VALUES ($1, '{}'::jsonb, $2, 'alipay', $3, 'trade.finished', $4, true)
        RETURNING id
        "#,
    )
    .bind(&alipay_info_id)
    .bind(alipay_created)
    .bind(&alipay_raw_id)
    .bind(alipay_created)
    .fetch_one(&pool)
    .await
    .expect("insert alipay webhook row");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/webhooks/billing/events?informational_event=true&provider=stripe&raw_event_id_prefix=evt_pg_{base}_&event_type=invoice.upcoming&provider_event_id={stripe_info_id}&provider_event_id_prefix=stripe:evt_pg_{base}_&event_created_from=2026-04-08T11:59:00Z&event_created_to=2026-04-08T12:01:00Z&created_from=2026-04-08T11:59:00Z&created_to=2026-04-08T12:01:00Z&id_min={}&id_max={}&sort=id_asc&limit=10&offset=0",
                    stripe_info_row.0,
                    stripe_info_row.0
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, filtered) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "filtered={filtered}");
    assert_eq!(filtered["total"].as_i64(), Some(1));
    assert_eq!(filtered["has_more"], false);
    assert!(filtered["next_offset"].is_null());
    let filtered_items = filtered["items"].as_array().expect("filtered items");
    assert_eq!(filtered_items.len(), 1);
    assert_eq!(
        filtered_items[0]["provider_event_id"].as_str(),
        Some(stripe_info_id.as_str())
    );
    assert_eq!(filtered_items[0]["provider"].as_str(), Some("stripe"));
    assert_eq!(
        filtered_items[0]["raw_event_id"].as_str(),
        Some(stripe_info_raw_id.as_str())
    );
    assert_eq!(
        filtered_items[0]["event_type"].as_str(),
        Some("invoice.upcoming")
    );
    assert_eq!(filtered_items[0]["is_informational_event"], true);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(
                    "/api/v1/webhooks/billing/events?provider=stripe&sort=id_desc&limit=1&offset=0",
                )
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, paged) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "paged={paged}");
    assert_eq!(paged["total"].as_i64(), Some(2));
    assert_eq!(paged["limit"].as_i64(), Some(1));
    assert_eq!(paged["offset"].as_i64(), Some(0));
    assert_eq!(paged["has_more"], true);
    assert_eq!(paged["next_offset"].as_i64(), Some(1));
    let paged_items = paged["items"].as_array().expect("paged items");
    assert_eq!(paged_items.len(), 1);
    assert_eq!(
        paged_items[0]["provider_event_id"].as_str(),
        Some(stripe_failed_id.as_str())
    );
    assert_eq!(paged_items[0]["id"].as_i64(), Some(stripe_failed_row.0));

    cleanup_billing_webhook_events(&pool, &created_ids).await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn me_profile_subscription_and_jobs_today_roundtrip() {
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
    let mut created_job_ids: Vec<Uuid> = Vec::new();

    let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;

    let period_end = chrono::DateTime::parse_from_rfc3339("2026-05-01T00:00:00Z")
        .unwrap()
        .with_timezone(&chrono::Utc);

    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (
          user_id,
          plan_tier,
          billing_currency,
          billing_provider,
          subscription_status,
          subscription_current_period_end_at,
          daily_job_quota
        )
        VALUES ($1, 'pro', 'USD', 'stripe', 'active', $2, 321)
        ON CONFLICT (user_id) DO UPDATE
        SET
          plan_tier = EXCLUDED.plan_tier,
          billing_currency = EXCLUDED.billing_currency,
          billing_provider = EXCLUDED.billing_provider,
          subscription_status = EXCLUDED.subscription_status,
          subscription_current_period_end_at = EXCLUDED.subscription_current_period_end_at,
          daily_job_quota = EXCLUDED.daily_job_quota,
          updated_at = NOW()
        "#,
    )
    .bind(sub)
    .bind(period_end)
    .execute(&pool)
    .await
    .expect("upsert app_user_profile");

    for i in 0..2 {
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/jobs")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .header("Idempotency-Key", format!("pg-me-roundtrip-{i}-{}", Uuid::new_v4()))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"kind":"{JOB_KIND_ASSET_GENERATE_IMAGE}","payload":{{"reason":"pg_me_roundtrip_{i}"}}}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, created_job) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "created_job={created_job}");
        created_job_ids.push(
            Uuid::parse_str(created_job["id"].as_str().expect("job id")).expect("parse job id"),
        );
    }

    let res = app
        .oneshot(
            Request::builder()
                .uri("/api/v1/me")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, me) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "me={me}");
    assert_eq!(me["plan_tier"].as_str(), Some("pro"));
    assert_eq!(me["billing_currency"].as_str(), Some("USD"));
    assert_eq!(me["billing_provider"].as_str(), Some("stripe"));
    assert_eq!(me["subscription_status"].as_str(), Some("active"));
    assert_eq!(
        me["subscription_current_period_end_at"].as_str(),
        Some("2026-05-01T00:00:00Z")
    );
    assert_eq!(me["daily_job_quota"].as_i64(), Some(321));
    assert!(
        me["jobs_today"].as_i64().unwrap_or_default() >= 2,
        "jobs_today should include the two enqueued jobs: {me}"
    );

    cleanup_jobs(&pool, &created_job_ids).await;
    let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn promote_staging_populates_assets_and_links() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    cleanup_promote_staging_fixtures(&pool).await;

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    sqlx::query(
        r#"INSERT INTO public.legacy_user_map (legacy_user_id, supabase_user_id)
           VALUES ($1, $2)
           ON CONFLICT (legacy_user_id) DO UPDATE SET supabase_user_id = EXCLUDED.supabase_user_id"#,
    )
    .bind(PROMO_LEGACY_USER)
    .bind(sub)
    .execute(&pool)
    .await
    .expect("legacy_user_map insert (requires existing auth.users id = CONTRACT_USER_SUB)");

    let project = serde_json::json!({
        "id": PROMO_PROJECT_LEG,
        "userId": PROMO_LEGACY_USER,
        "name": "pg_promote_project",
    });
    sqlx::query(
        r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_project', 'pg_promote_proj', $1)"#,
    )
    .bind(Json(project))
    .execute(&pool)
    .await
    .expect("staging o_project");

    let script = serde_json::json!({
        "id": PROMO_SCRIPT_LEG,
        "projectId": PROMO_PROJECT_LEG,
        "name": "pg_promote_script",
    });
    sqlx::query(
        r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_script', 'pg_promote_script', $1)"#,
    )
    .bind(Json(script))
    .execute(&pool)
    .await
    .expect("staging o_script");

    let asset = serde_json::json!({
        "id": PROMO_ASSET_LEG,
        "projectId": PROMO_PROJECT_LEG,
        "name": "pg_promote_hero",
        "type": "character",
        "describe": "promoted lead",
        "imageId": PROMO_IMAGE_LEG,
    });
    sqlx::query(
        r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_assets', 'pg_promote_asset', $1)"#,
    )
    .bind(Json(asset))
    .execute(&pool)
    .await
    .expect("staging o_assets");

    let link = serde_json::json!({
        "scriptId": PROMO_SCRIPT_LEG,
        "assetId": PROMO_ASSET_LEG,
    });
    sqlx::query(
        r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_scriptAssets', 'pg_promote_script_asset', $1)"#,
    )
    .bind(Json(link))
    .execute(&pool)
    .await
    .expect("staging o_scriptAssets");

    let art_style = serde_json::json!({
        "id": PROMO_ART_STYLE_LEG,
        "name": "pg_promote_style",
        "fileUrl": "/art/promo.jpg",
        "label": "pg_label",
        "prompt": "pg_prompt",
    });
    sqlx::query(
        r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_artStyle', 'pg_promote_art_style', $1)"#,
    )
    .bind(Json(art_style))
    .execute(&pool)
    .await
    .expect("staging o_artStyle");

    let o_prompt_row = serde_json::json!({
        "id": 1,
        "name": "事件提取",
        "type": "eventExtraction",
        "data": "pg_promoted_prompt_body_evt",
    });
    sqlx::query(
        r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_prompt', 'pg_promote_prompt', $1)"#,
    )
    .bind(Json(o_prompt_row))
    .execute(&pool)
    .await
    .expect("staging o_prompt");

    let o_image_row = serde_json::json!({
        "id": PROMO_IMAGE_LEG,
        "assetsId": PROMO_ASSET_LEG,
        "filePath": "/promo/history_corner.png",
        "state": "已完成",
    });
    sqlx::query(
        r#"INSERT INTO legacy_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_image', 'pg_promote_image', $1)"#,
    )
    .bind(Json(o_image_row))
    .execute(&pool)
    .await
    .expect("staging o_image");

    sqlx::query("SELECT 1 FROM public.promote_legacy_from_staging() LIMIT 1")
        .execute(&pool)
        .await
        .expect("promote_legacy_from_staging");

    let asset_rows: i64 =
        sqlx::query_scalar("SELECT COUNT(*)::bigint FROM public.app_asset WHERE legacy_id = $1")
            .bind(PROMO_ASSET_LEG)
            .fetch_one(&pool)
            .await
            .expect("count app_asset");
    assert_eq!(asset_rows, 1, "expected one promoted app_asset row");

    let link_rows: i64 = sqlx::query_scalar(
        r#"SELECT COUNT(*)::bigint FROM public.app_script_asset sa
           INNER JOIN public.app_script sc ON sc.id = sa.script_id
           INNER JOIN public.app_asset a ON a.id = sa.asset_id
           WHERE sc.legacy_id = $1 AND a.legacy_id = $2"#,
    )
    .bind(PROMO_SCRIPT_LEG)
    .bind(PROMO_ASSET_LEG)
    .fetch_one(&pool)
    .await
    .expect("count script_asset link");
    assert_eq!(link_rows, 1, "expected one promoted app_script_asset row");

    let promoted_img: i64 = sqlx::query_scalar(
        "SELECT COUNT(*)::bigint FROM public.app_asset_image WHERE legacy_image_id = $1",
    )
    .bind(PROMO_IMAGE_LEG)
    .fetch_one(&pool)
    .await
    .expect("count app_asset_image by legacy_image_id");
    assert_eq!(promoted_img, 1, "expected one promoted app_asset_image row");

    let style_rows: i64 = sqlx::query_scalar(
        "SELECT COUNT(*)::bigint FROM public.app_art_style WHERE legacy_id = $1",
    )
    .bind(PROMO_ART_STYLE_LEG)
    .fetch_one(&pool)
    .await
    .expect("count app_art_style");
    assert_eq!(style_rows, 1, "expected one promoted app_art_style row");

    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/art-styles")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, styles_body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "art_styles={styles_body}");
    let sitems = styles_body["items"].as_array().expect("style items");
    let sfound = sitems
        .iter()
        .find(|row| row["legacy_id"].as_i64() == Some(i64::from(PROMO_ART_STYLE_LEG)));
    let srow = sfound.expect("promoted art style in list");
    assert_eq!(srow["name"].as_str(), Some("pg_promote_style"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/legacy/{}/assets",
                    PROMO_PROJECT_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "assets list={list}");
    let items = list["items"].as_array().expect("items");
    let found = items
        .iter()
        .find(|row| row["legacy_id"].as_i64() == Some(i64::from(PROMO_ASSET_LEG)));
    let row = found.expect("promoted asset in list");
    assert_eq!(row["name"].as_str(), Some("pg_promote_hero"));
    assert_eq!(row["asset_type"].as_str(), Some("role"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/legacy/{}/assets?script_legacy_id={}",
                    PROMO_PROJECT_LEG, PROMO_SCRIPT_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, linked) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "linked={linked}");
    assert_eq!(linked["total"], 1);
    assert_eq!(
        linked["items"][0]["legacy_id"].as_i64(),
        Some(i64::from(PROMO_ASSET_LEG))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/legacy/{}/assets/corner-scape",
                    PROMO_PROJECT_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, corner) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "corner={corner}");
    let citems = corner["items"].as_array().expect("corner items");
    let hero = citems
        .iter()
        .find(|row| row["legacy_id"].as_i64() == Some(i64::from(PROMO_ASSET_LEG)))
        .expect("promoted asset in corner-scape");
    let hist = hero["history_images"].as_array().expect("history_images");
    assert_eq!(hist.len(), 1);
    assert_eq!(
        hist[0]["file_path"].as_str(),
        Some("/promo/history_corner.png")
    );
    assert_eq!(hist[0]["state"].as_str(), Some("已完成"));
    assert_eq!(
        hist[0]["legacy_image_id"].as_i64(),
        Some(i64::from(PROMO_IMAGE_LEG))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/legacy/{}/assets/{}/images",
                    PROMO_PROJECT_LEG, PROMO_ASSET_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, promo_list_img) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "promo_list_img={promo_list_img}");
    assert_eq!(
        promo_list_img["cover_legacy_image_id"].as_i64(),
        Some(i64::from(PROMO_IMAGE_LEG))
    );
    let plim = promo_list_img["items"]
        .as_array()
        .expect("promoted image list items");
    assert_eq!(plim.len(), 1);
    assert_eq!(plim[0]["selected"], true);
    assert_eq!(
        plim[0]["legacy_image_id"].as_i64(),
        Some(i64::from(PROMO_IMAGE_LEG))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/projects/legacy/{}/assets/{}",
                    PROMO_PROJECT_LEG, PROMO_ASSET_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"cover_legacy_image_id":null}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "clear cover via PATCH");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/legacy/{}/assets/{}/images",
                    PROMO_PROJECT_LEG, PROMO_ASSET_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cleared_list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "cleared_list={cleared_list}");
    assert!(cleared_list["cover_legacy_image_id"].is_null());
    let clim = cleared_list["items"].as_array().expect("cleared items");
    assert_eq!(clim[0]["selected"], false);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/projects/legacy/{}/assets/{}",
                    PROMO_PROJECT_LEG, PROMO_ASSET_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"cover_legacy_image_id":{}}}"#,
                    PROMO_IMAGE_LEG
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "restore cover via PATCH");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/legacy/{}/assets/{}/images",
                    PROMO_PROJECT_LEG, PROMO_ASSET_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, restored_list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "restored_list={restored_list}");
    assert_eq!(
        restored_list["cover_legacy_image_id"].as_i64(),
        Some(i64::from(PROMO_IMAGE_LEG))
    );
    let rlim = restored_list["items"].as_array().expect("restored items");
    assert_eq!(rlim[0]["selected"], true);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/prompts")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, prompts_body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "prompts={prompts_body}");
    let parr = prompts_body.as_array().expect("prompts json array");
    assert_eq!(parr.len(), 3);
    let p1 = parr
        .iter()
        .find(|row| row["id"].as_i64() == Some(1))
        .expect("prompt legacy id 1");
    assert_eq!(
        p1["data"].as_str(),
        Some("pg_promoted_prompt_body_evt"),
        "promoted o_prompt body should override file default"
    );

    cleanup_promote_staging_fixtures(&pool).await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn prompts_list_patch_roundtrip() {
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
    sqlx::query("DELETE FROM public.app_user_prompt WHERE owner_user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await
        .expect("cleanup app_user_prompt");

    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/prompts")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list={list}");
    let arr = list.as_array().expect("prompts array");
    assert_eq!(arr.len(), 3);

    let patch_body = r#"{"data":"pg_contract_prompt_patch_slot_2"}"#;
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri("/api/v1/prompts/2")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(patch_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patched={patched}");
    assert_eq!(
        patched["data"].as_str(),
        Some("pg_contract_prompt_patch_slot_2")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/prompts/2")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, one) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get one={one}");
    assert_eq!(one["id"].as_i64(), Some(2));
    assert_eq!(
        one["data"].as_str(),
        Some("pg_contract_prompt_patch_slot_2")
    );

    let res = app
        .oneshot(
            Request::builder()
                .uri("/api/v1/prompts")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, again) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "again={again}");
    let p2 = again
        .as_array()
        .expect("array")
        .iter()
        .find(|row| row["id"].as_i64() == Some(2))
        .expect("id 2");
    assert_eq!(p2["data"].as_str(), Some("pg_contract_prompt_patch_slot_2"));

    let _ = sqlx::query("DELETE FROM public.app_user_prompt WHERE owner_user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn art_styles_crud_roundtrip() {
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

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/art-styles")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"name":"pg_contract_art_style","prompt":"pg_contract_prompt"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "created={created}");
    let leg = created["legacy_id"].as_i64().expect("legacy_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/art-styles")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list={list}");
    assert!(list["total"].as_i64().unwrap_or(0) >= 1);
    let items = list["items"].as_array().expect("items");
    assert!(items
        .iter()
        .any(|row| row["legacy_id"].as_i64() == Some(i64::from(leg))));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/art-styles/legacy/{leg}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, one) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "one={one}");
    assert_eq!(one["name"].as_str(), Some("pg_contract_art_style"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/art-styles/legacy/{leg}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"label":"pg_contract_label"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patched={patched}");
    assert_eq!(patched["label"].as_str(), Some("pg_contract_label"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/art-styles/legacy/{leg}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), StatusCode::NO_CONTENT);

    let res = app
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/art-styles/legacy/{leg}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, gone) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NOT_FOUND, "gone={gone}");
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn art_styles_base64_cover_roundtrip() {
    use serde_json::json;

    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let tmp = tempfile::tempdir().expect("tempdir");
    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state_with_local_art_style_dir(
        pool.clone(),
        secret.clone(),
        tmp.path().to_path_buf(),
    ));

    let cover =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/art-styles")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "name": "pg_contract_art_style_cover",
                        "file_url": cover,
                        "prompt": "cover prompt"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "created={created}");
    let legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;
    let cover_uri = format!("/api/v1/art-styles/legacy/{legacy_id}/cover");
    assert_eq!(created["file_url"].as_str(), Some(cover_uri.as_str()));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(&cover_uri)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, bytes, ct) = read_bytes_response(res, 64 * 1024).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(ct.as_deref(), Some("image/png"));
    assert!(!bytes.is_empty(), "cover bytes should be non-empty");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/art-styles/legacy/{legacy_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"file_url":null}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patched={patched}");
    assert!(patched["file_url"].is_null());

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(&cover_uri)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, missing) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NOT_FOUND, "missing={missing}");

    let _ = sqlx::query("DELETE FROM public.app_art_style WHERE owner_user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn vendor_config_enable_update_roundtrip() {
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

    // Get vendors summary (initially no user config)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/vendors/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, summary) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "summary={summary}");
    assert_eq!(
        summary["source"].as_str(),
        Some("static_catalog_with_user_config")
    );
    let vendors = summary["vendors"].as_array().expect("vendors array");
    assert!(!vendors.is_empty());
    let first_vendor_id = vendors[0]["id"].as_i64().expect("vendor id") as i32;
    let first_vendor_id_str = format!("{}", first_vendor_id);

    // Initially no userConfig present
    assert!(vendors[0]["userConfig"].is_null() || vendors[0]["userConfig"].is_object());

    // Enable vendor
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/enable")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"id":"{}","enable":1}}"#,
                    first_vendor_id_str
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, enabled) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "enabled={enabled}");
    assert_eq!(
        enabled["vendorId"].as_str(),
        Some(first_vendor_id_str.as_str())
    );
    assert_eq!(enabled["enabled"].as_bool(), Some(true));

    // Verify summary shows enabled vendor with userConfig
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/vendors/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, summary2) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "summary2={summary2}");
    let vendors2 = summary2["vendors"].as_array().expect("vendors array");
    let v0 = vendors2
        .iter()
        .find(|v| v["id"].as_i64() == Some(i64::from(first_vendor_id)))
        .expect("vendor in summary2");
    assert_eq!(
        v0["userConfig"]["vendorId"].as_str(),
        Some(first_vendor_id_str.as_str())
    );
    assert_eq!(v0["userConfig"]["enabled"].as_bool(), Some(true));

    // Update vendor with display name and model selection
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/update")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"id":"{}","displayName":"My Vendor","selectedModels":["gpt-4o-mini"],"settings":{{"timeout":"30"}}}}"#,
                    first_vendor_id_str
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, updated) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "updated={updated}");
    assert_eq!(
        updated["vendorId"].as_str(),
        Some(first_vendor_id_str.as_str())
    );

    // Verify summary shows updated config
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/vendors/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, summary3) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "summary3={summary3}");
    let vendors3 = summary3["vendors"].as_array().expect("vendors array");
    let v0_3 = vendors3
        .iter()
        .find(|v| v["id"].as_i64() == Some(i64::from(first_vendor_id)))
        .expect("vendor");
    assert_eq!(
        v0_3["userConfig"]["displayName"].as_str(),
        Some("My Vendor")
    );
    let models = v0_3["userConfig"]["selectedModels"]
        .as_array()
        .expect("selectedModels");
    assert!(models.iter().any(|m| m.as_str() == Some("gpt-4o-mini")));
    assert_eq!(
        v0_3["userConfig"]["settings"]["timeout"].as_str(),
        Some("30")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/add")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"tsCode":"export default { id: 'probe' }"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, added) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "added={added}");
    let custom_vendor_id = added["vendorId"]
        .as_str()
        .expect("custom vendor id")
        .to_string();
    assert!(custom_vendor_id.starts_with("custom-"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/update-code")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"id":"{custom_vendor_id}","tsCode":"export default {{ updated: true }}"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, updated_code) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "updated_code={updated_code}");
    assert_eq!(
        updated_code["vendorId"].as_str(),
        Some(custom_vendor_id.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/vendors/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, summary4) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "summary4={summary4}");
    let vendors4 = summary4["vendors"].as_array().expect("vendors array");
    assert!(vendors4
        .iter()
        .any(|v| v["userConfig"]["vendorId"].as_str() == Some(custom_vendor_id.as_str())));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/code-from-link")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"link":"https://example.com/vendor.ts"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, linked) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "linked={linked}");
    let linked_vendor_id = linked["vendorId"]
        .as_str()
        .expect("linked vendor id")
        .to_string();
    assert!(linked_vendor_id.starts_with("linked-"));
    assert_eq!(
        linked["link"].as_str(),
        Some("https://example.com/vendor.ts")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/delete")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":"{custom_vendor_id}"}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, deleted) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "deleted={deleted}");
    assert_eq!(
        deleted["vendorId"].as_str(),
        Some(custom_vendor_id.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/delete")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":"{linked_vendor_id}"}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, deleted_linked) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "deleted_linked={deleted_linked}");
    assert_eq!(
        deleted_linked["vendorId"].as_str(),
        Some(linked_vendor_id.as_str())
    );

    // Disable vendor
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/enable")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"id":"{}","enable":0}}"#,
                    first_vendor_id_str
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, disabled) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "disabled={disabled}");
    assert_eq!(disabled["enabled"].as_bool(), Some(false));

    // Cleanup
    let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn novel_events_crud_roundtrip() {
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
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "created={created}");
    let project_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

    // Add novels first to have chapter_ids to associate
    let add_novel_body = format!(
        r#"{{"projectId":{},"data":[{{"index":1,"reel":"卷一","chapter":"第一章","chapterData":"第一章内容"}},{{"index":2,"reel":"卷一","chapter":"第二章","chapterData":"第二章内容"}}]}}"#,
        project_id
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/add-novel")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(add_novel_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "add novels");

    // Create event
    let create_body = format!(r#"{{"name":"测试事件","detail":"事件详情","chapterIds":[1,2]}}"#);
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/legacy/{}/novel-events",
                    project_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(create_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, event) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "create event={event}");
    assert_eq!(event["name"].as_str(), Some("测试事件"));
    let event_id = event["id"].as_i64().expect("event id") as i32;

    // List events
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/legacy/{}/novel-events",
                    project_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list={list}");
    assert_eq!(list["total"].as_i64(), Some(1));
    let items = list["items"].as_array().expect("items");
    assert_eq!(items.len(), 1);
    assert_eq!(items[0]["name"].as_str(), Some("测试事件"));
    let chapters = items[0]["chapterIndexes"].as_array().expect("chapters");
    assert_eq!(chapters.len(), 2);

    // Update event
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/projects/legacy/{}/novel-events/{}",
                    project_id, event_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"name":"更新后事件"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "update event");

    // Verify update
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/legacy/{}/novel-events",
                    project_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list2) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list2={list2}");
    assert_eq!(list2["items"][0]["name"].as_str(), Some("更新后事件"));

    // Delete event
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!(
                    "/api/v1/projects/legacy/{}/novel-events/{}",
                    project_id, event_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "delete event");

    // Verify deletion
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/legacy/{}/novel-events",
                    project_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, empty_list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "empty_list={empty_list}");
    assert_eq!(empty_list["total"].as_i64(), Some(0));

    // Cleanup
    let _ = sqlx::query("DELETE FROM public.app_novel WHERE project_id IN (SELECT id FROM public.app_project WHERE legacy_id = $1)")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn novel_events_generate_events_async_fallback_roundtrip() {
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
    let project_legacy_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

    let add_novel_body = format!(
        r#"{{"projectId":{},"data":[{{"index":1,"reel":"卷一","chapter":"第一章","chapterData":"第一章内容"}},{{"index":2,"reel":"卷一","chapter":"第二章","chapterData":"第二章内容"}}]}}"#,
        project_legacy_id
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/add-novel")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(add_novel_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, add_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "add_msg={add_msg}");

    let novel_rows: Vec<(i32,)> = sqlx::query_as(
        r#"
        SELECT n.legacy_id
        FROM public.app_novel n
        INNER JOIN public.app_project p ON p.id = n.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
        ORDER BY n.chapter_index ASC, n.legacy_id ASC
        "#,
    )
    .bind(project_legacy_id)
    .bind(sub)
    .fetch_all(&pool)
    .await
    .expect("list novel legacy ids");
    let novel_legacy_ids: Vec<i32> = novel_rows.into_iter().map(|(id,)| id).collect();
    assert_eq!(novel_legacy_ids.len(), 2, "expected two novels");

    sqlx::query(
        r#"
        UPDATE public.app_novel n
        SET event = '历史事件', event_state = 1, error_reason = NULL
        FROM public.app_project p
        WHERE n.project_id = p.id
          AND p.legacy_id = $1
          AND p.owner_user_id = $2
          AND n.legacy_id = ANY($3)
        "#,
    )
    .bind(project_legacy_id)
    .bind(sub)
    .bind(&novel_legacy_ids)
    .execute(&pool)
    .await
    .expect("seed existing events");

    let payload = serde_json::json!({
        "projectId": project_legacy_id,
        "novelIds": novel_legacy_ids,
        "concurrentCount": 2
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/events/generate-events")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(payload.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "generate-events body={body}");
    assert_eq!(body["message"].as_str(), Some("生成事件成功"));

    let reset_rows: Vec<(Option<String>, i32, Option<String>)> = sqlx::query_as(
        r#"
        SELECT n.event, n.event_state, n.error_reason
        FROM public.app_novel n
        INNER JOIN public.app_project p ON p.id = n.project_id
        WHERE p.legacy_id = $1
          AND p.owner_user_id = $2
          AND n.legacy_id = ANY($3)
        ORDER BY n.chapter_index ASC, n.legacy_id ASC
        "#,
    )
    .bind(project_legacy_id)
    .bind(sub)
    .bind(&novel_legacy_ids)
    .fetch_all(&pool)
    .await
    .expect("rows immediately after enqueue");
    assert!(
        reset_rows
            .iter()
            .all(|(event, state, reason)| event.is_none() && *state == 0 && reason.is_none()),
        "expected reset to pending before async extraction: {reset_rows:?}"
    );

    let mut final_rows: Vec<(i32, Option<String>, i32, Option<String>)> = Vec::new();
    for _ in 0..40 {
        final_rows = sqlx::query_as(
            r#"
            SELECT n.legacy_id, n.event, n.event_state, n.error_reason
            FROM public.app_novel n
            INNER JOIN public.app_project p ON p.id = n.project_id
            WHERE p.legacy_id = $1
              AND p.owner_user_id = $2
              AND n.legacy_id = ANY($3)
            ORDER BY n.chapter_index ASC, n.legacy_id ASC
            "#,
        )
        .bind(project_legacy_id)
        .bind(sub)
        .bind(&novel_legacy_ids)
        .fetch_all(&pool)
        .await
        .expect("poll extraction rows");
        if final_rows
            .iter()
            .all(|(_, _, state, _)| *state == -1 || *state == 1)
        {
            break;
        }
        tokio::time::sleep(std::time::Duration::from_millis(25)).await;
    }

    assert!(
        final_rows.iter().all(|(_, event, state, reason)| {
            event.is_none() && *state == -1 && reason.as_deref() == Some("llm_not_configured")
        }),
        "expected llm_not_configured fallback rows: {final_rows:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/novels/get-novel-event-state")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    serde_json::json!({ "ids": novel_legacy_ids }).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, state_rows) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "state_rows={state_rows}");
    let data = state_rows["data"].as_array().expect("state data array");
    assert_eq!(
        data.len(),
        2,
        "both novels should be visible in non-zero legacy event state list: {state_rows}"
    );
    assert!(
        data.iter()
            .all(|row| row["event_state"].as_i64() == Some(-1)),
        "legacy event_state should expose fallback failures: {state_rows}"
    );

    let _ = sqlx::query("DELETE FROM public.app_novel WHERE project_id IN (SELECT id FROM public.app_project WHERE legacy_id = $1)")
        .bind(project_legacy_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(project_legacy_id)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
async fn script_agent_plan_roundtrip() {
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
    let project_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/get-plan-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, initial_plan) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "initial_plan={initial_plan}");
    assert_eq!(initial_plan["code"].as_i64(), Some(200));
    assert_eq!(initial_plan["data"]["storySkeleton"].as_str(), Some(""));
    assert_eq!(
        initial_plan["data"]["adaptationStrategy"].as_str(),
        Some("")
    );

    let set_body = serde_json::json!({
        "projectId": project_id,
        "agentType": "scriptAgent",
        "data": {
            "storySkeleton": "三幕短剧",
            "adaptationStrategy": "先冲突后反转",
            "script": [
                { "name": "第1集", "content": "第一集内容" },
                { "name": "第2集", "content": "第二集内容" }
            ]
        }
    })
    .to_string();
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/set-plan-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(set_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, set_ok) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "set_ok={set_ok}");
    assert_eq!(set_ok["code"].as_i64(), Some(200));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/get-plan-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, fetched_plan) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "fetched_plan={fetched_plan}");
    assert_eq!(
        fetched_plan["data"]["data"]["storySkeleton"].as_str(),
        Some("三幕短剧")
    );
    assert_eq!(
        fetched_plan["data"]["data"]["adaptationStrategy"].as_str(),
        Some("先冲突后反转")
    );
    let plan_id = fetched_plan["data"]["id"].as_i64().expect("plan id");
    let scripts = fetched_plan["data"]["data"]["script"]
        .as_array()
        .expect("scripts array");
    assert_eq!(scripts.len(), 2);
    assert_eq!(scripts[0]["name"].as_str(), Some("第1集"));
    assert_eq!(scripts[0]["content"].as_str(), Some("第一集内容"));
    let script_row_id = scripts[0]["id"].as_i64().expect("script row id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/set-plan-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    serde_json::json!({
                        "projectId": project_id,
                        "agentType": "scriptAgent",
                        "data": {
                            "storySkeleton": "四幕短剧",
                            "adaptationStrategy": "强化人物弧光",
                            "script": [
                                { "name": "第1集", "content": "第一集修订版" }
                            ]
                        }
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, set_again_ok) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "set_again_ok={set_again_ok}");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/get-plan-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, fetched_after_update) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "fetched_after_update={fetched_after_update}"
    );
    assert_eq!(
        fetched_after_update["data"]["data"]["storySkeleton"].as_str(),
        Some("四幕短剧")
    );
    let scripts_after_update = fetched_after_update["data"]["data"]["script"]
        .as_array()
        .expect("scripts_after_update");
    assert_eq!(
        scripts_after_update.len(),
        2,
        "existing unnamed rows preserved"
    );
    assert_eq!(
        scripts_after_update[0]["content"].as_str(),
        Some("第一集修订版")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/update-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    serde_json::json!({
                        "id": plan_id,
                        "data": {
                            "storySkeleton": "终稿大纲",
                            "adaptationStrategy": "保留反转",
                            "script": [
                                { "id": script_row_id, "content": "终稿正文" }
                            ]
                        }
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, updated_data) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "updated_data={updated_data}");
    assert_eq!(updated_data["data"].as_str(), Some("更新成功"));

    let stored_plan: Option<Value> = sqlx::query_scalar(
        r#"
        SELECT plan_data
        FROM public.app_script_agent_plan
        WHERE owner_user_id = $1
          AND project_id IN (
            SELECT id FROM public.app_project WHERE legacy_id = $2
          )
          AND agent_key = 'scriptAgent'
        "#,
    )
    .bind(sub)
    .bind(project_id)
    .fetch_optional(&pool)
    .await
    .expect("select plan_data");
    let stored_plan = stored_plan.expect("stored plan_data");
    assert_eq!(stored_plan["storySkeleton"].as_str(), Some("终稿大纲"));
    assert_eq!(stored_plan["adaptationStrategy"].as_str(), Some("保留反转"));
    assert_eq!(
        stored_plan["script"][0]["id"].as_i64(),
        Some(i64::from(script_row_id))
    );
    assert_eq!(
        stored_plan["script"][0]["content"].as_str(),
        Some("终稿正文")
    );

    let _ = sqlx::query(
        "DELETE FROM public.app_script WHERE project_id IN (SELECT id FROM public.app_project WHERE legacy_id = $1)",
    )
    .bind(project_id)
    .execute(&pool)
    .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
async fn settings_memory_config_and_clear_agent_memories_roundtrip() {
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
    let project_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/memory-config")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, default_cfg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "default_cfg={default_cfg}");
    assert_eq!(default_cfg["messagesPerSummary"].as_i64(), Some(10));
    assert_eq!(default_cfg["modelDtype"].as_str(), Some("fp16"));

    let custom_cfg = r#"{"messagesPerSummary":12,"shortTermLimit":7,"summaryMaxLength":640,"summaryLimit":11,"ragLimit":4,"deepRetrieveSummaryLimit":6,"modelOnnxFile":["custom","onnx","model.onnx"],"modelDtype":"int8"}"#;
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/memory-config")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(custom_cfg))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, saved) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "saved={saved}");
    assert_eq!(saved["message"].as_str(), Some("保存设置成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/memory-config")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, fetched_cfg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "fetched_cfg={fetched_cfg}");
    assert_eq!(fetched_cfg["messagesPerSummary"].as_i64(), Some(12));
    assert_eq!(fetched_cfg["shortTermLimit"].as_i64(), Some(7));
    assert_eq!(fetched_cfg["modelDtype"].as_str(), Some("int8"));

    let stored_cfg: Option<Json<MemoryConfig>> =
        sqlx::query_scalar("SELECT memory_config FROM public.app_user_profile WHERE user_id = $1")
            .bind(sub)
            .fetch_optional(&pool)
            .await
            .expect("select memory_config");
    let stored_cfg = stored_cfg.expect("stored memory_config").0;
    assert_eq!(stored_cfg.messages_per_summary, 12);
    assert_eq!(stored_cfg.model_dtype, "int8");

    for body in [
        format!(
            r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7,"role":"user","content":"episode scoped memory"}}"#
        ),
        format!(
            r#"{{"projectId":{project_id},"agentType":"scriptAgent","role":"assistant","content":"project scoped memory"}}"#
        ),
    ] {
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/agents/memory/append")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, appended) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "appended={appended}");
        assert!(appended["id"].as_str().is_some());
    }

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/agents/memory/query")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, episode_memory) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "episode_memory={episode_memory}");
    assert_eq!(episode_memory.as_array().map(|a| a.len()), Some(1));
    assert_eq!(
        episode_memory[0]["content"][0]["data"].as_str(),
        Some("episode scoped memory")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/memory-config/clear-agent-memories")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cleared) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "cleared={cleared}");
    assert_eq!(cleared["ok"].as_bool(), Some(true));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/agents/memory/query")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, episode_memory_after_clear) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "episode_memory_after_clear={episode_memory_after_clear}"
    );
    assert_eq!(
        episode_memory_after_clear.as_array().map(|a| a.len()),
        Some(0)
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/agents/memory/query")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, project_memory) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "project_memory={project_memory}");
    assert_eq!(project_memory.as_array().map(|a| a.len()), Some(1));
    assert_eq!(
        project_memory[0]["content"][0]["data"].as_str(),
        Some("project scoped memory")
    );

    let _ = sqlx::query(
        "DELETE FROM public.app_agent_memory WHERE owner_user_id = $1 AND legacy_project_id = $2",
    )
    .bind(sub)
    .bind(project_id)
    .execute(&pool)
    .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
async fn vendor_credential_store_get_delete_roundtrip() {
    let _guard = vendor_credential_test_lock().await;
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

    // Set encryption key for test
    std::env::set_var(
        "TOONFLOW_VENDOR_CREDENTIAL_KEY",
        "test-encryption-key-for-contract-tests",
    );

    let vendor_id = "openai";

    // Store credential
    let store_body = format!(
        r#"{{"vendorId":"{}","apiKey":"sk-test1234567890","apiSecret":"secret123","apiToken":"token123"}}"#,
        vendor_id
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/credential")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(store_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, stored) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "store credential={stored}");
    assert_eq!(stored["vendorId"].as_str(), Some(vendor_id));
    assert_eq!(stored["keyHint"].as_str(), Some("...7890"));
    assert_eq!(stored["hasSecret"].as_bool(), Some(true));
    assert_eq!(stored["hasToken"].as_bool(), Some(true));
    assert_eq!(
        stored["message"].as_str(),
        Some("Credential stored securely")
    );

    // Get credential metadata
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/settings/vendors/credential/{}", vendor_id))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, got) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get credential={got}");
    assert_eq!(got["vendorId"].as_str(), Some(vendor_id));
    assert_eq!(got["keyHint"].as_str(), Some("...7890"));
    assert_eq!(got["hasSecret"].as_bool(), Some(true));
    assert_eq!(got["hasToken"].as_bool(), Some(true));

    // Delete credential
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/settings/vendors/credential/{}", vendor_id))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, deleted) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "delete credential={deleted}");
    assert_eq!(deleted["vendorId"].as_str(), Some(vendor_id));
    assert_eq!(deleted["message"].as_str(), Some("Credential deleted"));

    // Verify deletion - should get 404
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/settings/vendors/credential/{}", vendor_id))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "credential should be deleted"
    );

    // Cleanup
    let _ = sqlx::query("DELETE FROM public.app_vendor_credential WHERE owner_user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;

    // Clean up env var
    std::env::remove_var("TOONFLOW_VENDOR_CREDENTIAL_KEY");
}
