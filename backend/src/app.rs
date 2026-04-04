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
    use axum::http::{Request, StatusCode};
    use serde_json::Value;
    use tower::ServiceExt;

    use super::build_router;
    use crate::notify_hub::WsNotifyHub;
    use crate::state::AppState;

    const MAX_JSON: usize = 65_536;

    fn test_addr() -> SocketAddr {
        SocketAddr::from(([127, 0, 0, 1], 42_042))
    }

    fn smoke_state() -> AppState {
        AppState {
            pool: None,
            jwt_secret: Some(b"not-used-for-these-routes".to_vec()),
            llm: None,
            http_client: reqwest::Client::new(),
            notify: WsNotifyHub::new(),
        }
    }

    async fn get_json(uri: &str) -> (StatusCode, Value) {
        let app = build_router(smoke_state());
        let res = app
            .oneshot(
                Request::builder()
                    .uri(uri)
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let status = res.status();
        let body = axum::body::to_bytes(res.into_body(), MAX_JSON)
            .await
            .unwrap();
        let v: Value = serde_json::from_slice(&body).expect("response body is json");
        (status, v)
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
}
