//! Toonflow HTTP API entrypoint.
//! Default listen port: 8666 (override with `PORT`).

mod agent_memory;
mod app;
mod art_styles;
mod assets;
mod assets_generate;
mod auth;
mod billing;
mod director_manual;
mod error;
mod general_legacy;
mod harness;
mod jobs;
mod json_patch;
mod llm;
mod models_catalog;
mod notify_hub;
mod novel_events;
mod novels;
mod novels_legacy;
mod ops;
mod production_legacy;
mod project_legacy;
mod projects;
mod prompts;
mod quality_review;
mod queue;
mod quota;
mod rate_limit;
mod request_id_mw;
mod script_agent;
mod script_asset_extract;
mod scripts;
mod scripts_legacy;
mod settings_about;
mod settings_agent_deploy;
mod settings_danger;
mod settings_dev;
mod settings_memory_config;
mod settings_vendors;
mod skills;
mod state;
mod storyboards;
mod tasks_legacy;
mod usage;
mod vendor_credential;
mod video_providers;
mod visual_manual;

use std::net::SocketAddr;

use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

#[tokio::main]
async fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.get(1).is_some_and(|s| s == "__harness_isolate_echo__") {
        harness::isolate::stdio_echo_child();
    }

    let _ = dotenvy::dotenv();

    if let Some(result) = ops::maybe_run_from_args(args.iter().skip(1).cloned()).await {
        if let Err(err) = result {
            eprintln!("{err:#}");
            std::process::exit(1);
        }
        return;
    }

    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .with(tracing_subscriber::fmt::layer())
        .init();

    let state = state::AppState::from_env()
        .await
        .expect("failed to initialize app state (check DATABASE_URL)");

    let port: u16 = std::env::var("PORT")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(8666);

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("bind failed");

    tracing::info!(%addr, "toonflow-server listening");

    let worker_state = state.clone();
    tokio::spawn(async move {
        jobs::worker::run(worker_state).await;
    });

    let app = app::build_router(state);
    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .await
    .expect("server failed");
}
