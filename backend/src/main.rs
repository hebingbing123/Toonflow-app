//! Toonflow HTTP API entrypoint.
//! Default listen port: 8666 (override with `PORT`).

mod agent_memory;
mod app;
mod auth;
mod billing;
mod error;
mod harness;
mod jobs;
mod json_patch;
mod llm;
mod models_catalog;
mod notify_hub;
mod projects;
mod rate_limit;
mod request_id_mw;
mod scripts;
mod skills;
mod state;
mod storyboards;
mod usage;

use std::net::SocketAddr;

use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

#[tokio::main]
async fn main() {
    if std::env::args()
        .nth(1)
        .as_deref()
        .is_some_and(|s| s == "__harness_isolate_echo__")
    {
        harness::isolate::stdio_echo_child();
    }

    let _ = dotenvy::dotenv();

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
