//! 组合域路由、速率限制、中间件和 CORS。

use crate::assets;
use crate::billing;
use crate::harness;
use crate::http_kit::rate_limit::{
    governor_layer_from_env, strict_endpoint_governor_layer, user_governor_layer,
};
use crate::http_kit::request_id_mw::inject_request_id_into_json_errors;
use crate::jobs;
use crate::manuals;
use crate::metering;
use crate::narrative;
use crate::production_legacy;
use crate::projects;
use crate::prompting;
use crate::scripting;
use crate::settings;
use crate::state::AppState;
use crate::vendor;

use axum::{
    http::{header, HeaderName, Method},
    middleware::from_fn,
    routing::get,
    Router,
};

use crate::harness::ws::upgrade::ws_upgrade;

use super::handlers;

pub fn build_router(state: AppState) -> Router {
    let cors = tower_http::cors::CorsLayer::new()
        .allow_origin(tower_http::cors::Any)
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

    // Layer 3: Strict endpoint rate limiting for high-frequency endpoints (~5 req/s per endpoint)
    let strict_limited = Router::new()
        .merge(harness::http::router())
        .merge(jobs::router())
        .layer(strict_endpoint_governor_layer());

    // Layer 2: Per-user rate limiting (~10 req/s per user)
    let user_limited = Router::new()
        .merge(strict_limited)
        .merge(settings::agent_memory::router())
        .merge(vendor::catalog::router())
        .merge(projects::routes::router())
        .merge(manuals::director::router())
        .merge(manuals::art_styles::router())
        .merge(narrative::novels::router())
        .merge(narrative::events::router())
        .merge(production_legacy::router())
        .merge(assets::router())
        .merge(scripting::scripts::router())
        .merge(scripting::agent::router())
        .merge(scripting::asset_extract::router())
        .merge(narrative::storyboards::router())
        .merge(prompting::skills::router())
        .merge(manuals::visual::router())
        .merge(metering::usage::router())
        .merge(prompting::prompts::router())
        .merge(prompting::quality::routes())
        .merge(settings::about::router())
        .merge(settings::agent_deploy::router())
        .merge(settings::danger::router())
        .merge(settings::dev::router())
        .merge(settings::memory_config::router())
        .merge(settings::vendors::router())
        .route("/api/v1/me", get(handlers::me))
        .route("/api/v1/ws", get(ws_upgrade))
        // Layer 1: Global IP-based rate limiting (~50 req/s per IP)
        .layer(governor_layer_from_env())
        // Layer 2: Per-user rate limiting applied after global
        .layer(user_governor_layer());

    Router::new()
        .merge(user_limited)
        .merge(billing::router())
        .route("/health", get(handlers::health))
        .route("/api/v1/health", get(handlers::health))
        .route("/api/v1/ping", get(handlers::ping))
        .route("/api/v1/version", get(handlers::version))
        .route("/api/v1/ready", get(handlers::ready))
        .with_state(state)
        .layer(from_fn(inject_request_id_into_json_errors))
        .layer(tower_http::request_id::PropagateRequestIdLayer::x_request_id())
        .layer(tower_http::request_id::SetRequestIdLayer::x_request_id(
            tower_http::request_id::MakeRequestUuid,
        ))
        .layer(tower_http::trace::TraceLayer::new_for_http())
        .layer(cors)
}
