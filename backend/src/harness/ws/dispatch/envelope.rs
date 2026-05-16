//! 客户端 JSON 信封（入站 WebSocket 文本帧）。

use serde::Deserialize;
use serde_json::Value;

#[derive(Debug, Deserialize)]
pub(crate) struct ClientEnvelope {
    #[serde(rename = "type")]
    pub msg_type: String,
    pub schema_version: i32,
    pub payload: Value,
    pub request_id: Option<String>,
}
