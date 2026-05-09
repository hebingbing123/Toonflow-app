use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

pub(crate) const ACCOUNT_DELETE_CONFIRM_PHRASE: &str = "DELETE MY ACCOUNT";

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct AccountExportCreateBody {
    #[serde(default)]
    pub include_audit_logs: bool,
    #[serde(default = "default_include_notifications")]
    pub include_notifications: bool,
}

const fn default_include_notifications() -> bool {
    true
}

#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct AccountExportJobRecord {
    pub id: Uuid,
    pub numeric_task_id: i64,
    pub status: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub error_message: Option<String>,
    pub file_name: Option<String>,
    pub content_type: Option<String>,
    pub byte_size: Option<i64>,
    pub download_ready: bool,
}

#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct AccountExportsResponse {
    pub items: Vec<AccountExportJobRecord>,
    pub active_count: i64,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct AccountDeleteBody {
    pub confirm_phrase: String,
    #[serde(default)]
    pub acknowledge_irreversible: bool,
}

#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct AccountDeleteResponse {
    pub deleted_user_id: Uuid,
    pub deleted_at: DateTime<Utc>,
    pub owned_workspace_count: i64,
    pub workspace_membership_count: i64,
    pub owned_project_count: i64,
    pub generation_job_count: i64,
    pub notification_count: i64,
    pub local_cleanup_paths: Vec<String>,
}
