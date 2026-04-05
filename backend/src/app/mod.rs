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
    use axum::http::{Request, StatusCode};
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
    use tower::ServiceExt;
    use uuid::Uuid;

    use super::build_router;
    use super::jwt_fixture;
    use crate::notify_hub::WsNotifyHub;
    use crate::state::AppState;

    const MAX_JSON: usize = 65_536;
    /// JWT `sub` and `app_project.owner_user_id` for this run.
    const CONTRACT_USER_SUB: &str = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";

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
}
