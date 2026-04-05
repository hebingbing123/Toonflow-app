//! Composes domain routers, rate limiting, middleware, and CORS.

use crate::agent_memory;
use crate::art_styles;
use crate::assets;
use crate::assets_generate;
use crate::billing;
use crate::director_manual;
use crate::general_legacy;
use crate::harness;
use crate::jobs;
use crate::models_catalog;
use crate::novels;
use crate::novels_legacy;
use crate::production_legacy;
use crate::project_legacy;
use crate::projects;
use crate::prompts;
use crate::rate_limit::governor_layer_from_env;
use crate::request_id_mw::inject_request_id_into_json_errors;
use crate::script_agent;
use crate::script_asset_extract;
use crate::scripts;
use crate::scripts_legacy;
use crate::settings_about;
use crate::settings_agent_deploy;
use crate::settings_danger;
use crate::settings_dev;
use crate::settings_memory_config;
use crate::settings_vendors;
use crate::skills;
use crate::state::AppState;
use crate::storyboards;
use crate::tasks_legacy;
use crate::usage;
use crate::visual_manual;

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

    let rate_limited = Router::new()
        .merge(agent_memory::router())
        .merge(models_catalog::router())
        .merge(projects::router())
        .merge(project_legacy::router())
        .merge(director_manual::router())
        .merge(general_legacy::router())
        .merge(art_styles::router())
        .merge(novels::router())
        .merge(novels_legacy::router())
        .merge(production_legacy::router())
        .merge(assets::router())
        .merge(assets_generate::router())
        .merge(scripts::router())
        .merge(scripts_legacy::router())
        .merge(script_agent::router())
        .merge(script_asset_extract::router())
        .merge(storyboards::router())
        .merge(tasks_legacy::router())
        .merge(skills::router())
        .merge(visual_manual::router())
        .merge(harness::http::router())
        .merge(jobs::router())
        .merge(usage::router())
        .merge(prompts::router())
        .merge(settings_about::router())
        .merge(settings_agent_deploy::router())
        .merge(settings_danger::router())
        .merge(settings_dev::router())
        .merge(settings_memory_config::router())
        .merge(settings_vendors::router())
        .route("/api/v1/me", get(handlers::me))
        .route("/api/v1/ws", get(ws_upgrade))
        .layer(governor_layer_from_env());

    Router::new()
        .merge(rate_limited)
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
