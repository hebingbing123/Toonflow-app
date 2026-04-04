use crate::harness::ws_connection;
use crate::state::AppState;

use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Query, State};
use axum::response::IntoResponse;
use serde::Deserialize;
use serde_json::{json, Value};

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

pub(crate) async fn send_envelope(
    socket: &mut WebSocket,
    msg_type: &str,
    schema_version: i32,
    payload: Value,
    request_id: Option<&str>,
) -> bool {
    let mut v = json!({
        "type": msg_type,
        "schema_version": schema_version,
        "payload": payload,
    });
    if let Some(rid) = request_id {
        v["request_id"] = json!(rid);
    }
    let Ok(text) = serde_json::to_string(&v) else {
        return false;
    };
    socket.send(Message::Text(text.into())).await.is_ok()
}

pub(crate) async fn send_error(
    socket: &mut WebSocket,
    code: &str,
    message: &str,
    request_id: Option<&str>,
) -> bool {
    let mut payload = json!({
        "code": code,
        "message": message,
    });
    if let Some(rid) = request_id {
        payload["request_id"] = json!(rid);
    }
    send_envelope(socket, "error.occurred", 1, payload, request_id).await
}

pub(crate) fn error_occurred_json(code: &str, message: &str, request_id: Option<&str>) -> String {
    let mut inner = json!({
        "code": code,
        "message": message,
    });
    if let Some(r) = request_id {
        inner["request_id"] = json!(r);
    }
    let mut v = json!({
        "type": "error.occurred",
        "schema_version": 1,
        "payload": inner,
    });
    if let Some(r) = request_id {
        v["request_id"] = json!(r);
    }
    serde_json::to_string(&v).expect("json")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_occurred_json_includes_request_id_in_payload() {
        let rid = "550e8400-e29b-41d4-a716-446655440000";
        let s = error_occurred_json("x", "y", Some(rid));
        let v: Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v.get("request_id").and_then(Value::as_str), Some(rid));
        let payload = v.get("payload").unwrap();
        assert_eq!(payload.get("request_id").and_then(Value::as_str), Some(rid));
        assert_eq!(payload.get("code").and_then(Value::as_str), Some("x"));
    }
}
