use crate::agent_memory;
use crate::auth::require_claims;
use crate::billing;
use crate::error::ApiError;
use crate::jobs;
use crate::models_catalog;
use crate::projects;
use crate::scripts;
use crate::skills;
use crate::state::AppState;
use crate::storyboards;
use crate::usage;

use axum::{
    extract::State,
    http::{header, HeaderMap, HeaderName, Method},
    middleware::from_fn,
    routing::get,
    Json, Router,
};

use crate::rate_limit::governor_layer_from_env;
use crate::request_id_mw::inject_request_id_into_json_errors;
use crate::ws::ws_upgrade;
use serde::Serialize;
use sqlx::FromRow;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use uuid::Uuid;

#[derive(Serialize)]
struct HealthResponse {
    status: &'static str,
    service: &'static str,
}

#[derive(Serialize)]
struct VersionResponse {
    service: &'static str,
    version: &'static str,
    /// Present when the binary was built with env **`TOONFLOW_GIT_SHA`** set (compile-time `option_env!`).
    #[serde(skip_serializing_if = "Option::is_none")]
    git_sha: Option<&'static str>,
}

#[derive(Serialize)]
struct ReadyResponse {
    status: &'static str,
    database: &'static str,
}

#[derive(Serialize)]
struct MeResponse {
    sub: Uuid,
    #[serde(skip_serializing_if = "Option::is_none")]
    email: Option<String>,
    /// From `app_user_profile` when connected; defaults to `free` when no row.
    plan_tier: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    billing_currency: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    billing_provider: Option<String>,
}

#[derive(FromRow)]
struct UserProfileRow {
    plan_tier: String,
    billing_currency: Option<String>,
    billing_provider: Option<String>,
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok",
        service: "toonflow-server",
    })
}

async fn version() -> Json<VersionResponse> {
    Json(VersionResponse {
        service: "toonflow-server",
        version: env!("CARGO_PKG_VERSION"),
        git_sha: option_env!("TOONFLOW_GIT_SHA"),
    })
}

async fn ready(State(state): State<AppState>) -> Result<Json<ReadyResponse>, ApiError> {
    match &state.pool {
        None => Ok(Json(ReadyResponse {
            status: "ok",
            database: "not_configured",
        })),
        Some(pool) => {
            sqlx::query_scalar::<_, i32>("SELECT 1")
                .fetch_one(pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            Ok(Json(ReadyResponse {
                status: "ok",
                database: "connected",
            }))
        }
    }
}

async fn me(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<MeResponse>, ApiError> {
    let claims = require_claims(&state, &headers)?;
    let sub = Uuid::parse_str(claims.sub.trim()).map_err(|_| ApiError::BadToken)?;

    let (plan_tier, billing_currency, billing_provider) = if let Some(pool) = state.pool.as_ref() {
        let row = sqlx::query_as::<_, UserProfileRow>(
            r#"
                SELECT plan_tier, billing_currency, billing_provider
                FROM app_user_profile
                WHERE user_id = $1
                "#,
        )
        .bind(sub)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        match row {
            Some(r) => (r.plan_tier, r.billing_currency, r.billing_provider),
            None => ("free".to_string(), None, None),
        }
    } else {
        ("free".to_string(), None, None)
    };

    Ok(Json(MeResponse {
        sub,
        email: claims.email,
        plan_tier,
        billing_currency,
        billing_provider,
    }))
}

pub fn build_router(state: AppState) -> Router {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PATCH,
            Method::PUT,
            Method::DELETE,
        ])
        .allow_headers([
            header::AUTHORIZATION,
            header::CONTENT_TYPE,
            header::ACCEPT,
            HeaderName::from_static("x-request-id"),
        ])
        .expose_headers([HeaderName::from_static("x-request-id")]);

    let rate_limited = Router::new()
        .merge(agent_memory::router())
        .merge(models_catalog::router())
        .merge(projects::router())
        .merge(scripts::router())
        .merge(storyboards::router())
        .merge(skills::router())
        .merge(jobs::router())
        .merge(usage::router())
        .route("/api/v1/me", get(me))
        .route("/api/v1/ws", get(ws_upgrade))
        .layer(governor_layer_from_env());

    Router::new()
        .merge(rate_limited)
        .merge(billing::router())
        .route("/health", get(health))
        .route("/api/v1/health", get(health))
        .route("/api/v1/version", get(version))
        .route("/api/v1/ready", get(ready))
        .with_state(state)
        .layer(from_fn(inject_request_id_into_json_errors))
        .layer(tower_http::request_id::PropagateRequestIdLayer::x_request_id())
        .layer(tower_http::request_id::SetRequestIdLayer::x_request_id(
            tower_http::request_id::MakeRequestUuid,
        ))
        .layer(TraceLayer::new_for_http())
        .layer(cors)
}

#[cfg(test)]
mod contract_smoke_tests {
    use std::net::SocketAddr;

    use axum::body::Body;
    use axum::extract::ConnectInfo;
    use axum::http::header;
    use axum::http::{Request, StatusCode};
    use chrono::Utc;
    use jsonwebtoken::{encode, EncodingKey, Header};
    use serde::Serialize;
    use serde_json::Value;
    use tower::ServiceExt;
    use uuid::Uuid;

    use super::build_router;
    use crate::notify_hub::WsNotifyHub;
    use crate::state::AppState;

    const MAX_JSON: usize = 65_536;
    /// Shared with [`SmokeJwtClaims`] encoding; must satisfy Supabase-style `aud` + HS256 verify.
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

    #[derive(Serialize)]
    struct SmokeJwtClaims {
        sub: String,
        exp: i64,
        aud: &'static str,
    }

    fn test_jwt(sub: Uuid) -> String {
        encode(
            &Header::default(),
            &SmokeJwtClaims {
                sub: sub.to_string(),
                exp: Utc::now().timestamp() + 86_400,
                aud: "authenticated",
            },
            &EncodingKey::from_secret(TEST_JWT_SECRET),
        )
        .expect("encode test jwt")
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
}
