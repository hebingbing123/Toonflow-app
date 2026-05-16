//! Request/response types and shared constants for script HTTP handlers.

use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow, Serialize)]
pub struct ScriptRow {
    pub id: Uuid,
    pub project_id: Uuid,
    #[serde(rename = "numeric_id")]
    #[sqlx(rename = "numeric_id")]
    pub numeric_id: i32,
    pub name: Option<String>,
    pub content: Option<String>,
    pub extract_state: Option<i32>,
    pub create_time_ms: Option<i64>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(crate) struct PatchScriptBody {
    #[serde(default)]
    pub(crate) name: Option<Value>,
    #[serde(default)]
    pub(crate) content: Option<Value>,
    #[serde(default)]
    pub(crate) extract_state: Option<Value>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(crate) struct CreateScriptBody {
    #[serde(default)]
    pub(crate) name: Option<String>,
    #[serde(default)]
    pub(crate) content: Option<String>,
    #[serde(default)]
    pub(crate) extract_state: Option<i32>,
}

/// Body for **`POST …/projects/{project_id}/scripts/batch-add`** (project UUID in path).
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct BatchAddScriptDataBody {
    pub(crate) data: Vec<BatchAddScriptItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct BatchAddScriptItem {
    pub(crate) script_name: String,
    pub(crate) script_data: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct BatchAddScriptResponse {
    pub(crate) message: String,
    pub(crate) inserted: i32,
    pub(crate) scripts: Vec<ScriptRow>,
}

/// Advisory lock key for allocating globally unique `app_script.numeric_id`.
pub(crate) const ADV_LOCK_SCRIPT_NUMERIC_ID: i64 = 884_422_002;

/// Electron `exportScript` accepted an array of ids; cap to bound work per request.
pub(crate) const MAX_SCRIPT_EXPORT: usize = 500;
/// Electron `pollScriptAssets` polled many rows; cap list size.
pub(crate) const MAX_SCRIPT_EXTRACT_POLL: usize = 2_000;

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct ExportScriptsBody {
    pub(crate) numeric_ids: Vec<i32>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct ScriptExtractPollBody {
    pub(crate) numeric_ids: Vec<i32>,
}

#[derive(Debug, Serialize, FromRow)]
pub(crate) struct ScriptExtractPollRow {
    #[serde(rename = "numeric_id")]
    #[sqlx(rename = "numeric_id")]
    pub(crate) numeric_id: i32,
    pub(crate) extract_state: Option<i32>,
    pub(crate) error_reason: Option<String>,
}

// ── `POST /api/v1/projects/{project_id}/scripts/get-script-api` ───────────────

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(crate) struct GetScriptApiNameBody {
    #[serde(default)]
    pub(crate) name: Option<String>,
}

#[derive(Debug, FromRow)]
pub(crate) struct GetScriptApiScriptRow {
    pub(crate) id: Uuid,
    #[sqlx(rename = "numeric_id")]
    pub(crate) numeric_id: i32,
    pub(crate) name: Option<String>,
    pub(crate) content: Option<String>,
    pub(crate) extract_state: Option<i32>,
    pub(crate) error_reason: Option<String>,
    pub(crate) create_time_ms: Option<i64>,
}

#[derive(Debug, Serialize)]
pub(crate) struct GetScriptApiRelatedAssetBrief {
    pub(crate) id: i32,
    pub(crate) name: String,
}

#[derive(Debug, Serialize)]
pub(crate) struct GetScriptApiScriptListItem {
    pub(crate) id: i32,
    pub(crate) name: Option<String>,
    pub(crate) content: Option<String>,
    #[serde(rename = "extractState")]
    pub(crate) extract_state: Option<i32>,
    #[serde(rename = "errorReason")]
    pub(crate) error_reason: Option<String>,
    #[serde(rename = "createTime")]
    pub(crate) create_time_ms: Option<i64>,
    #[serde(rename = "relatedAssets")]
    pub(crate) related_assets: Vec<GetScriptApiRelatedAssetBrief>,
}

#[derive(Debug, Serialize)]
pub(crate) struct GetScriptApiResponse {
    pub(crate) data: Vec<GetScriptApiScriptListItem>,
}
