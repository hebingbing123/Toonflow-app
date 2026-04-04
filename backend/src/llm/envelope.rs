//! JSON lines pushed to the WebSocket outbound channel (`type` + `schema_version` + `payload`).

use serde_json::{json, Value};

pub(crate) fn envelope(msg_type: &str, payload: Value, request_id: Option<&str>) -> String {
    let mut v = json!({
        "type": msg_type,
        "schema_version": 1,
        "payload": payload,
    });
    if let Some(r) = request_id {
        v["request_id"] = json!(r);
    }
    serde_json::to_string(&v).expect("serialize envelope")
}
