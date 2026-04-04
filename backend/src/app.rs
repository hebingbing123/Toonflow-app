use crate::auth::require_claims;
use crate::billing;
use crate::error::ApiError;
use crate::jobs;
use crate::projects;
use crate::scripts;
use crate::skills;
use crate::state::AppState;
use crate::storyboards;

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
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use uuid::Uuid;

#[derive(Serialize)]
struct HealthResponse {
    status: &'static str,
    service: &'static str,
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
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok",
        service: "toonflow-server",
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
    Ok(Json(MeResponse {
        sub,
        email: claims.email,
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
        .merge(projects::router())
        .merge(scripts::router())
        .merge(storyboards::router())
        .merge(skills::router())
        .merge(jobs::router())
        .route("/api/v1/me", get(me))
        .route("/api/v1/ws", get(ws_upgrade))
        .layer(governor_layer_from_env());

    Router::new()
        .merge(rate_limited)
        .merge(billing::router())
        .route("/health", get(health))
        .route("/api/v1/health", get(health))
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
