//! 制作流程 JSON API 请求体。

use serde::Deserialize;
use serde_json::Value;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct GetFlowDataBody {
    pub(crate) project_id: i32,
    pub(crate) episodes_id: i32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct SaveFlowDataBody {
    pub(crate) project_id: i32,
    pub(crate) episodes_id: i32,
    pub(crate) data: Value,
    /// Optional version timestamp (ISO 8601) for optimistic locking.
    /// If provided, the save will fail with 409 Conflict if the current
    /// `app_production_flow.updated_at` doesn't match this value.
    #[serde(default)]
    pub(crate) flow_version: Option<String>,
}
