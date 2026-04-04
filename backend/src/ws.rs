//! Axum WebSocket upgrade for `/api/v1/ws`. Outbound framing lives in [`crate::harness::ws_outbound`].

use crate::harness::ws_connection;
use crate::state::AppState;

use axum::extract::ws::WebSocketUpgrade;
use axum::extract::{Query, State};
use axum::response::IntoResponse;
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct WsQuery {
    pub access_token: Option<String>,
}

pub async fn ws_upgrade(
    ws: WebSocketUpgrade,
    Query(query): Query<WsQuery>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| ws_connection::run_socket(socket, state, query.access_token))
}
