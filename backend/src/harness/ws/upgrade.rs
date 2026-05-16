//! Axum `GET /api/v1/ws` 升级处理器。

use axum::extract::ws::WebSocketUpgrade;
use axum::extract::{Query, State};
use axum::response::IntoResponse;
use serde::Deserialize;

use crate::harness::ws::connection;
use crate::state::AppState;

#[derive(Debug, Deserialize, utoipa::IntoParams)]
#[into_params(parameter_in = Query)]
pub struct WsQuery {
    /// Supabase JWT when the client cannot set `Authorization` on the WebSocket handshake (typical browsers).
    pub access_token: Option<String>,
}

#[utoipa::path(
    get,
    path = "/api/v1/ws",
    operation_id = "websocketUpgrade",
    tag = "websocket",
    description = include_str!("../../openapi_spec/ws_protocol_description.md"),
    params(WsQuery),
    responses(
        (status = 101, description = "Switching Protocols — WebSocket established (RFC 6455)"),
        (status = 400, description = "Bad Request — invalid upgrade or handshake"),
        (status = 401, description = "Unauthorized — JWT rejected when required by server policy")
    )
)]
pub async fn ws_upgrade(
    ws: WebSocketUpgrade,
    Query(query): Query<WsQuery>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| connection::run_socket(socket, state, query.access_token))
}
