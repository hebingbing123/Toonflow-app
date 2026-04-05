//! HTTP router composition and core JSON routes (`/health`, `/api/v1/me`, …).

mod handlers;
mod router;

pub use router::build_router;

#[cfg(test)]
mod jwt_fixture {
    use chrono::Utc;
    use jsonwebtoken::{encode, EncodingKey, Header};
    use serde::Serialize;
    use uuid::Uuid;

    #[derive(Serialize)]
    struct SmokeJwtClaims {
        sub: String,
        exp: i64,
        aud: &'static str,
    }

    pub(crate) fn encode_supabase_style(sub: Uuid, secret: &[u8]) -> String {
        encode(
            &Header::default(),
            &SmokeJwtClaims {
                sub: sub.to_string(),
                exp: Utc::now().timestamp() + 86_400,
                aud: "authenticated",
            },
            &EncodingKey::from_secret(secret),
        )
        .expect("encode test jwt")
    }
}

#[cfg(test)]
mod contract_smoke_tests {
    use std::net::SocketAddr;

    use axum::body::Body;
    use axum::extract::ConnectInfo;
    use axum::http::header;
    use axum::http::{Method, Request, StatusCode};
    use serde_json::Value;
    use tower::ServiceExt;
    use uuid::Uuid;

    use super::build_router;
    use super::jwt_fixture;
    use crate::notify_hub::WsNotifyHub;
    use crate::state::AppState;

    const MAX_JSON: usize = 65_536;
    /// Shared with [`jwt_fixture::encode_supabase_style`]; must satisfy Supabase-style `aud` + HS256 verify.
    const TEST_JWT_SECRET: &[u8] = b"contract-smoke-jwt-secret-bytes-32chars!";

    fn test_addr() -> SocketAddr {
        SocketAddr::from(([127, 0, 0, 1], 42_042))
    }

    fn smoke_state() -> AppState {
        AppState {
            pool: None,
            jwt_secret: Some(TEST_JWT_SECRET.to_vec()),
            llm: None,
            http_client: reqwest::Client::new(),
            notify: WsNotifyHub::new(),
        }
    }

    fn test_jwt(sub: Uuid) -> String {
        jwt_fixture::encode_supabase_style(sub, TEST_JWT_SECRET)
    }

    async fn oneshot_json(req: Request<Body>) -> (StatusCode, Value) {
        let app = build_router(smoke_state());
        let res = app.oneshot(req).await.unwrap();
        let status = res.status();
        let body = axum::body::to_bytes(res.into_body(), MAX_JSON)
            .await
            .unwrap();
        let v: Value = serde_json::from_slice(&body).expect("response body is json");
        (status, v)
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

    async fn patch_json_bearer(uri: &str, token: &str, json_body: &str) -> (StatusCode, Value) {
        oneshot_json(
            Request::builder()
                .method(Method::PATCH)
                .uri(uri)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(json_body.to_string()))
                .unwrap(),
        )
        .await
    }

    async fn put_empty_bearer(uri: &str, token: &str) -> (StatusCode, Value) {
        oneshot_json(
            Request::builder()
                .method(Method::PUT)
                .uri(uri)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
    }

    async fn delete_empty_bearer(uri: &str, token: &str) -> (StatusCode, Value) {
        oneshot_json(
            Request::builder()
                .method(Method::DELETE)
                .uri(uri)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
    }

    #[tokio::test]
    async fn health_routes_ok_without_database() {
        for uri in ["/health", "/api/v1/health"] {
            let (status, v) = get_json(uri).await;
            assert_eq!(status, StatusCode::OK, "uri={uri}");
            assert_eq!(v["status"], "ok");
            assert_eq!(v["service"], "toonflow-server");
        }
    }

    #[tokio::test]
    async fn version_shape_matches_contract() {
        let (status, v) = get_json("/api/v1/version").await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(v["service"], "toonflow-server");
        assert!(v["version"].as_str().is_some_and(|s| !s.is_empty()));
    }

    #[tokio::test]
    async fn ready_without_database_reports_not_configured() {
        let (status, v) = get_json("/api/v1/ready").await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(v["status"], "ok");
        assert_eq!(v["database"], "not_configured");
    }

    #[tokio::test]
    async fn models_unauthorized_without_bearer() {
        let (status, v) = get_json("/api/v1/models").await;
        assert_eq!(status, StatusCode::UNAUTHORIZED);
        assert_eq!(v["code"], "unauthorized");
    }

    #[tokio::test]
    async fn models_list_ok_with_supabase_style_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = get_json_bearer("/api/v1/models", &token).await;
        assert_eq!(status, StatusCode::OK);
        let arr = v.as_array().expect("models list is array");
        assert!(!arr.is_empty(), "embedded catalog must expose models");
        assert!(arr[0].get("id").is_some());
        assert!(arr[0].get("model_name").is_none()); // list entry uses legacy shape: value, type, …
        assert!(arr[0].get("value").is_some());
    }

    #[tokio::test]
    async fn harness_tools_ok_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = get_json_bearer("/api/v1/harness/tools", &token).await;
        assert_eq!(status, StatusCode::OK);
        let tools = v["tools"].as_array().expect("tools array");
        assert!(!tools.is_empty());
        let names: Vec<&str> = tools.iter().filter_map(|t| t["name"].as_str()).collect();
        assert!(names.contains(&"echo"));
        assert!(names.contains(&"wasm.probe"));
    }

    #[tokio::test]
    async fn skills_summary_ok_with_jwt_when_skills_tree_present() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = get_json_bearer("/api/v1/skills/summary", &token).await;
        assert_eq!(status, StatusCode::OK);
        assert!(
            v["markdown_file_count"].as_u64().unwrap_or(0) > 0,
            "repo ships backend/data/skills markdown"
        );
    }

    #[tokio::test]
    async fn models_detail_ok_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let uri = "/api/v1/models/detail?model_id=1%3Agpt-4o-mini";
        let (status, v) = get_json_bearer(uri, &token).await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(v["model_name"], "gpt-4o-mini");
        assert_eq!(v["vendor_id"], 1);
        assert_eq!(v["type"], "text");
    }

    #[tokio::test]
    async fn skills_list_ok_with_jwt_when_skills_tree_present() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = get_json_bearer("/api/v1/skills", &token).await;
        assert_eq!(status, StatusCode::OK);
        let arr = v.as_array().expect("skills list is array");
        assert!(!arr.is_empty());
        assert!(arr.iter().any(|e| {
            e.get("path")
                .and_then(Value::as_str)
                .is_some_and(|p| p.ends_with(".md"))
        }));
    }

    #[tokio::test]
    async fn skill_content_ok_with_jwt_for_known_file() {
        let token = test_jwt(Uuid::nil());
        let uri = "/api/v1/skills/content?path=script_execution_script.md";
        let (status, v) = get_json_bearer(uri, &token).await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(v["path"], "script_execution_script.md");
        assert!(v["content"].as_str().is_some_and(|s| !s.trim().is_empty()));
    }

    #[tokio::test]
    async fn project_assets_list_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = get_json_bearer("/api/v1/projects/legacy/1/assets", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn project_assets_list_pagination_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) =
            get_json_bearer("/api/v1/projects/legacy/1/assets?page=1&limit=2", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    /// Combined list filters (parity with legacy **`getAssetsApi`** query surface).
    #[tokio::test]
    async fn project_assets_list_combined_filters_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let uri = "/api/v1/projects/legacy/1/assets?script_legacy_id=1&asset_type=role&name=probe&page=1&limit=2";
        let (status, v) = get_json_bearer(uri, &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn project_assets_create_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/projects/legacy/1/assets",
            &token,
            r#"{"name":"contract_smoke_role","type":"role"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn script_asset_link_put_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) =
            put_empty_bearer("/api/v1/projects/legacy/1/scripts/1/assets/1", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn script_asset_unlink_delete_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) =
            delete_empty_bearer("/api/v1/projects/legacy/1/scripts/1/assets/1", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn project_asset_get_by_legacy_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = get_json_bearer("/api/v1/projects/legacy/1/assets/1", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn project_asset_patch_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = patch_json_bearer(
            "/api/v1/projects/legacy/1/assets/1",
            &token,
            r#"{"name":"patched"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn project_asset_delete_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = delete_empty_bearer("/api/v1/projects/legacy/1/assets/1", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn project_novels_list_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = get_json_bearer("/api/v1/projects/legacy/1/novels", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn project_novels_list_pagination_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) =
            get_json_bearer("/api/v1/projects/legacy/1/novels?page=1&limit=5", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn project_novels_create_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = post_json_bearer(
            "/api/v1/projects/legacy/1/novels",
            &token,
            r#"{"chapter":"smoke"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn project_novel_get_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = get_json_bearer("/api/v1/projects/legacy/1/novels/1", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn project_novel_patch_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = patch_json_bearer(
            "/api/v1/projects/legacy/1/novels/1",
            &token,
            r#"{"chapter":"x"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn project_novel_delete_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = delete_empty_bearer("/api/v1/projects/legacy/1/novels/1", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn projects_summary_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = get_json_bearer("/api/v1/projects/summary", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn art_styles_list_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = get_json_bearer("/api/v1/art-styles", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn art_styles_create_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) =
            post_json_bearer("/api/v1/art-styles", &token, r#"{"name":"smoke_style"}"#).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn art_style_get_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = get_json_bearer("/api/v1/art-styles/legacy/1", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn art_style_patch_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) =
            patch_json_bearer("/api/v1/art-styles/legacy/1", &token, r#"{"label":"x"}"#).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }

    #[tokio::test]
    async fn art_style_delete_requires_database_with_jwt() {
        let token = test_jwt(Uuid::nil());
        let (status, v) = delete_empty_bearer("/api/v1/art-styles/legacy/1", &token).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(v["code"], "database_error");
    }
}

/// Postgres-backed contract checks (opt-in: **`#[ignore]`** so default **`cargo test`** stays DB-free).
#[cfg(test)]
mod pg_contract_tests {
    use std::net::SocketAddr;

    use axum::body::Body;
    use axum::extract::ConnectInfo;
    use axum::http::header;
    use axum::http::{Method, Request, StatusCode};
    use axum::response::Response;
    use serde_json::Value;
    use sqlx::postgres::PgPoolOptions;
    use sqlx::types::Json;
    use sqlx::PgPool;
    use tower::ServiceExt;
    use uuid::Uuid;

    use super::build_router;
    use super::jwt_fixture;
    use crate::notify_hub::WsNotifyHub;
    use crate::state::AppState;

    const MAX_JSON: usize = 65_536;
    /// JWT `sub` and `app_project.owner_user_id` for this run.
    const CONTRACT_USER_SUB: &str = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";

    /// Isolated legacy ids for **`promote_staging_populates_assets_and_links`** (avoid API allocator range).
    const PROMO_LEGACY_USER: i32 = 5_010_000;
    const PROMO_PROJECT_LEG: i32 = 5_010_001;
    const PROMO_SCRIPT_LEG: i32 = 5_010_002;
    const PROMO_ASSET_LEG: i32 = 5_010_003;
    const PROMO_ART_STYLE_LEG: i32 = 5_010_004;

    async fn cleanup_promote_staging_fixtures(pool: &PgPool) {
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
               WHERE source_row_key IN ('pg_promote_proj','pg_promote_script','pg_promote_asset','pg_promote_script_asset','pg_promote_art_style')"#,
        )
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

    fn contract_state(pool: sqlx::PgPool, jwt_secret: String) -> AppState {
        AppState {
            pool: Some(pool),
            jwt_secret: Some(jwt_secret.into_bytes()),
            llm: None,
            http_client: reqwest::Client::new(),
            notify: WsNotifyHub::new(),
        }
    }

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

        sqlx::query("SELECT 1 FROM public.promote_legacy_from_staging() LIMIT 1")
            .execute(&pool)
            .await
            .expect("promote_legacy_from_staging");

        let asset_rows: i64 = sqlx::query_scalar(
            "SELECT COUNT(*)::bigint FROM public.app_asset WHERE legacy_id = $1",
        )
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

        cleanup_promote_staging_fixtures(&pool).await;
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
}
