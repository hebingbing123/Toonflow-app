//! Toonflow HTTP API 入口点。
//!
//! 默认监听端口：8666（可通过 `PORT` 覆盖）。

use std::net::SocketAddr;

use toonflow_server::{app, billing, harness, jobs, publish, state};
#[tokio::main]
async fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.get(1).is_some_and(|s| s == "__harness_isolate_echo__") {
        harness::isolate::stdio_echo_child();
    }
    if args
        .get(1)
        .is_some_and(|s| s == "__harness_isolate_echo_pool__")
    {
        harness::isolate::stdio_echo_pool_child();
    }

    let _ = dotenvy::dotenv();

    if let Some(result) = app::ops::maybe_run_from_args(args.iter().skip(1).cloned()).await {
        if let Err(err) = result {
            eprintln!("{err:#}");
            std::process::exit(1);
        }
        return;
    }

    toonflow_server::telemetry::init_tracing_subscriber();

    harness::isolate::warm_isolate_pool_prefork().await;

    let state = state::AppState::from_env()
        .await
        .expect("failed to initialize app state (check DATABASE_URL)");

    let harness_alert_cfg = std::sync::Arc::new(harness::alert::WasmAlertConfig::from_env());
    harness::alert::spawn_harness_alert_eval_task(state.clone(), harness_alert_cfg);

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

    let publish_worker_state = state.clone();
    tokio::spawn(async move {
        publish::worker::run(publish_worker_state).await;
    });

    // Task 4.3: Billing reconciliation worker (shadow period monitoring)
    let reconciliation_state = state.clone();
    tokio::spawn(async move {
        billing::run_reconciliation_worker(reconciliation_state).await;
    });

    let app = app::build_router(state);
    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .await
    .expect("server failed");
}
