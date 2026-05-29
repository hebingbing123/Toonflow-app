use crate::assets;
use crate::billing;
use crate::harness;
use crate::http_kit::rate_limit::{
    governor_layer_from_env, search_governor_layer, strict_endpoint_governor_layer,
    user_governor_layer,
};
use crate::http_kit::request_id_mw::inject_request_id_into_json_errors;
use crate::jobs;
use crate::manuals;
use crate::metering;
use crate::middleware::tracing::trace_request;
use crate::narrative;
use crate::production;
use crate::projects;
use crate::prompting;
use crate::publish;
use crate::scripting;
use crate::search;
use crate::settings;
use crate::state::AppState;
use crate::vendor;
use crate::workspaces;

use axum::{
    http::{header, HeaderName, Method},
    middleware::{from_fn, from_fn_with_state},
    routing::{get, patch},
    Router,
};

use crate::harness::ws::upgrade::ws_upgrade;
use crate::internal_ops::INTERNAL_OPS_HEADER;

use super::super::handlers;
use super::super::openapi;

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
            header::ACCEPT_LANGUAGE,
            HeaderName::from_static("x-api-key"),
            HeaderName::from_static("x-request-id"),
            HeaderName::from_static(INTERNAL_OPS_HEADER),
        ])
        .expose_headers([HeaderName::from_static("x-request-id")]);

    // Layer 3: Strict endpoint rate limiting for high-frequency endpoints (~5 req/s per endpoint)
    let strict_limited = Router::new()
        .merge(harness::http::router())
        .merge(jobs::router())
        .layer(strict_endpoint_governor_layer());

    // Search-specific rate limiting: 60 req/min per user (Requirement 9.7)
    let search_limited = Router::new()
        .merge(search::routes::router())
        .layer(search_governor_layer());

    // Layer 2: Per-user rate limiting (~10 req/s per user)
    let user_limited = Router::new()
        .merge(strict_limited)
        .merge(search_limited)
        .merge(workspaces::router())
        .merge(settings::agent_memory::router())
        .merge(vendor::catalog::router())
        .merge(projects::routes::router())
        .merge(publish::router())
        .merge(manuals::director::router())
        .merge(manuals::art_styles::router())
        .merge(narrative::novels::router())
        .merge(narrative::events::router())
        .merge(production::router())
        .merge(assets::router())
        .merge(scripting::scripts::router())
        .merge(scripting::agent::router())
        .merge(scripting::asset_extract::router())
        .merge(narrative::storyboards::router())
        .merge(prompting::skills::router())
        .merge(prompting::skill_versions::router())
        .merge(manuals::visual::router())
        .merge(metering::usage::router())
        .merge(prompting::prompts::router())
        .merge(prompting::quality::routes())
        .merge(prompting::benchmark::registry_routes())
        .merge(prompting::benchmark::experiments_routes())
        .merge(prompting::benchmark::judge_routes())
        .merge(prompting::benchmark::review_queue_routes())
        .merge(prompting::benchmark::observation_assets_routes())
        .merge(prompting::benchmark::memory_profiles_routes())
        .merge(prompting::benchmark::promotion_gate_routes())
        .merge(settings::about::router())
        .merge(settings::admin_console::router())
        .merge(settings::api_keys::router())
        .merge(settings::account::router())
        .merge(settings::agent_deploy::router())
        .merge(settings::content_compliance::router())
        .merge(settings::danger::router())
        .merge(settings::dev::router())
        .merge(settings::help_hub::router())
        .merge(settings::memory_config::router())
        .merge(settings::notifications::router())
        .merge(settings::outbound_webhooks::router())
        .merge(settings::platform_config::router())
        .merge(settings::studio_ui::router())
        .merge(settings::vendors::router())
        .route("/api/v1/me", get(handlers::me))
        .route(
            "/api/v1/me/current-workspace",
            patch(handlers::patch_current_workspace),
        )
        .route("/api/v1/ws", get(ws_upgrade))
        // Layer 1: Global IP-based rate limiting (~50 req/s per IP)
        .layer(governor_layer_from_env())
        .layer(from_fn_with_state(
            state.clone(),
            crate::auth::middleware::api_key_auth_middleware,
        ))
        .layer(from_fn_with_state(
            state.clone(),
            crate::auth::middleware::user_governance_middleware,
        ))
        // Layer 2: Per-user rate limiting applied after global
        .layer(user_governor_layer());

    let router = Router::new()
        .route("/api/v1/openapi.yaml", get(openapi::openapi_yaml))
        .route("/api/v1/docs", get(openapi::swagger_ui))
        .merge(user_limited)
        .merge(billing::router())
        .route("/health", get(handlers::health))
        .route("/api/v1/health", get(handlers::health))
        .route("/api/v1/ping", get(handlers::ping))
        .route("/api/v1/version", get(handlers::version))
        .route("/api/v1/ready", get(handlers::ready))
        // Metrics endpoints
        .route("/api/v1/metrics", get(handlers::get_metrics))
        .route("/api/v1/metrics/sli", get(handlers::get_sli_status))
        .route(
            "/api/v1/metrics/sli/definitions",
            get(handlers::get_sli_definitions),
        )
        .with_state(state)
        .layer(from_fn(trace_request))
        .layer(from_fn(inject_request_id_into_json_errors))
        .layer(tower_http::request_id::PropagateRequestIdLayer::x_request_id())
        .layer(tower_http::request_id::SetRequestIdLayer::x_request_id(
            tower_http::request_id::MakeRequestUuid,
        ))
        .layer(tower_http::trace::TraceLayer::new_for_http())
        .layer(cors);

    crate::marketing_site::merge_fallback(router)
}
