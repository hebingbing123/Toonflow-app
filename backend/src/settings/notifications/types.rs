use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct NotificationRecord {
    pub id: i64,
    pub user_id: Uuid,
    pub workspace_id: Option<Uuid>,
    pub project_id: Option<Uuid>,
    pub project_numeric_id: Option<i32>,
    pub job_id: Option<Uuid>,
    pub notification_type: String,
    pub title: String,
    pub message: String,
    pub link_path: Option<String>,
    pub payload: Value,
    pub file_path: Option<String>,
    pub changed_at: Option<DateTime<Utc>>,
    pub read_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct ListNotificationsEnvelope {
    pub items: Vec<NotificationRecord>,
    pub unread_count: i64,
    pub has_more: bool,
    pub next_before_id: Option<i64>,
}

#[derive(Debug, Clone, Deserialize, Default, IntoParams, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[into_params(parameter_in = Query)]
pub struct ListNotificationsQuery {
    #[serde(default)]
    pub notification_type: Option<String>,
    #[serde(default)]
    pub unread_only: Option<bool>,
    #[serde(default)]
    pub query: Option<String>,
    #[serde(default)]
    pub limit: Option<i64>,
    #[serde(default)]
    pub before_id: Option<i64>,
    #[serde(default)]
    pub include_muted: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct MarkNotificationsReadBody {
    pub ids: Vec<i64>,
    pub read: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct MarkNotificationsReadEnvelope {
    pub items: Vec<NotificationRecord>,
    pub unread_count: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct MarkAllNotificationsReadResponse {
    pub updated_count: i64,
    pub unread_count: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct DeleteNotificationsBody {
    pub ids: Vec<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct DeleteNotificationsResponse {
    pub deleted_count: i64,
    pub unread_count: i64,
}

#[derive(Debug, Clone)]
pub struct NotificationRecordPayload {
    pub user_id: Uuid,
    pub workspace_id: Option<Uuid>,
    pub project_id: Option<Uuid>,
    pub project_numeric_id: Option<i32>,
    pub job_id: Option<Uuid>,
    pub notification_type: String,
    pub title: String,
    pub message: String,
    pub link_path: Option<String>,
    pub payload: Value,
    pub file_path: Option<String>,
    pub changed_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct NotificationPreferences {
    #[serde(default)]
    pub muted_notification_types: Vec<String>,
    #[serde(default)]
    pub muted_workspace_ids: Vec<Uuid>,
    #[serde(default)]
    pub muted_project_ids: Vec<Uuid>,
    #[serde(default = "default_true")]
    pub deliver_critical_even_muted: bool,
    #[serde(default = "default_content_compliance_cleared_throttle_minutes")]
    pub content_compliance_cleared_throttle_minutes: i64,
    #[serde(default)]
    pub content_compliance_cleared_stage_throttle_minutes: HashMap<String, i64>,
    #[serde(default)]
    pub content_compliance_cleared_templates: Vec<ContentComplianceClearedTemplateItem>,
    #[serde(default)]
    pub content_compliance_cleared_template_order: Vec<String>,
    #[serde(default)]
    pub content_compliance_cleared_recent_template_ids: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct NotificationPreferencesAuditMeta {
    pub updated_at: Option<DateTime<Utc>>,
    #[serde(default)]
    pub updated_by: String,
    #[serde(default)]
    pub source: String,
}

impl Default for NotificationPreferencesAuditMeta {
    fn default() -> Self {
        Self {
            updated_at: None,
            updated_by: "self".to_string(),
            source: "manual".to_string(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct NotificationPreferencesEnvelope {
    pub preferences: NotificationPreferences,
    pub audit: NotificationPreferencesAuditMeta,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct ImportNotificationPreferencesBody {
    pub envelope: NotificationPreferencesEnvelope,
}

const fn default_true() -> bool {
    true
}

const fn default_content_compliance_cleared_throttle_minutes() -> i64 {
    30
}

fn default_template_kind() -> String {
    "custom".to_string()
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct ApplyNotificationPreferencesTemplateBody {
    pub template: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct ContentComplianceAlertSyncItem {
    pub stage: String,
    pub level: String,
    pub count: i64,
    pub title: String,
    pub message: String,
    #[serde(default)]
    pub link_path: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct SyncContentComplianceAlertsBody {
    pub alerts: Vec<ContentComplianceAlertSyncItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct SyncContentComplianceAlertsResponse {
    pub synced_count: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct ContentComplianceClearedTemplatePolicy {
    pub global_minutes: i64,
    pub stage_minutes: HashMap<String, i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct ContentComplianceClearedTemplateItem {
    pub id: String,
    pub label: String,
    pub description: String,
    pub policy: ContentComplianceClearedTemplatePolicy,
    #[serde(default = "default_template_kind")]
    pub kind: String,
    #[serde(default = "default_true")]
    pub can_edit: bool,
    #[serde(default = "default_true")]
    pub can_delete: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct ListContentComplianceClearedTemplatesResponse {
    pub templates: Vec<ContentComplianceClearedTemplateItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct UpsertContentComplianceClearedTemplateBody {
    pub template: ContentComplianceClearedTemplateItem,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct DeleteContentComplianceClearedTemplateBody {
    pub id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct UpsertContentComplianceClearedTemplateResponse {
    pub templates: Vec<ContentComplianceClearedTemplateItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct DeleteContentComplianceClearedTemplateResponse {
    pub deleted: bool,
    pub templates: Vec<ContentComplianceClearedTemplateItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct ApplyContentComplianceClearedTemplateBody {
    pub id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct ApplyContentComplianceClearedTemplateResponse {
    pub applied: bool,
    pub templates: Vec<ContentComplianceClearedTemplateItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct ReorderContentComplianceClearedTemplatesBody {
    pub ids: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct ReorderContentComplianceClearedTemplatesResponse {
    pub templates: Vec<ContentComplianceClearedTemplateItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct ExportContentComplianceClearedTemplatesResponse {
    pub templates: Vec<ContentComplianceClearedTemplateItem>,
    pub order: Vec<String>,
    pub recent: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct ImportContentComplianceClearedTemplatesBody {
    pub templates: Vec<ContentComplianceClearedTemplateItem>,
    #[serde(default)]
    pub order: Vec<String>,
    #[serde(default)]
    pub recent: Vec<String>,
    #[serde(default)]
    pub mode: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct ImportContentComplianceClearedTemplatesResponse {
    pub imported_count: i64,
    pub templates: Vec<ContentComplianceClearedTemplateItem>,
    pub order: Vec<String>,
    pub recent: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct ContentComplianceClearedTemplateAuditItem {
    pub at: DateTime<Utc>,
    pub actor_user_id: Uuid,
    pub action: String,
    pub template_id: String,
    pub note: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct ListWorkspaceContentComplianceClearedTemplatesResponse {
    pub workspace_id: Uuid,
    pub can_manage: bool,
    pub templates: Vec<ContentComplianceClearedTemplateItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct ListWorkspaceContentComplianceClearedTemplateAuditResponse {
    pub workspace_id: Uuid,
    pub can_manage: bool,
    pub items: Vec<ContentComplianceClearedTemplateAuditItem>,
    pub has_more: bool,
    pub next_offset: Option<i64>,
}

#[derive(Debug, Clone, Deserialize, Default, IntoParams, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[into_params(parameter_in = Query)]
pub struct ListWorkspaceContentComplianceClearedTemplateAuditQuery {
    #[serde(default)]
    pub template_id: Option<String>,
    #[serde(default)]
    pub action: Option<String>,
    #[serde(default)]
    pub limit: Option<i64>,
    #[serde(default)]
    pub offset: Option<i64>,
    #[serde(default)]
    pub start_at: Option<String>,
    #[serde(default)]
    pub end_at: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Default, IntoParams, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[into_params(parameter_in = Query)]
pub struct ExportWorkspaceContentComplianceClearedTemplateAuditQuery {
    #[serde(default)]
    pub template_id: Option<String>,
    #[serde(default)]
    pub action: Option<String>,
    #[serde(default)]
    pub start_at: Option<String>,
    #[serde(default)]
    pub end_at: Option<String>,
    #[serde(default)]
    pub format: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct ExportWorkspaceContentComplianceClearedTemplateAuditResponse {
    pub format: String,
    pub file_name: String,
    pub content: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct WorkspaceContentComplianceClearedTemplateAuditExportRecord {
    pub exported_at: DateTime<Utc>,
    pub actor_user_id: Uuid,
    pub format: String,
    pub file_name: String,
    pub template_id: Option<String>,
    pub action: Option<String>,
    pub start_at: Option<String>,
    pub end_at: Option<String>,
    /// Populated when the export ran as an async **`app_generation_job`** (download via export-jobs file route).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub job_id: Option<Uuid>,
    /// **`sync`** (inline **`GET …/audit/export`**) vs **`async`** (background job artifact).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub export_delivery: Option<String>,
}

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct WorkspaceSharedAuditExportEnqueueBody {
    #[serde(default)]
    pub format: Option<String>,
    #[serde(default)]
    pub template_id: Option<String>,
    #[serde(default)]
    pub action: Option<String>,
    #[serde(default)]
    pub start_at: Option<String>,
    #[serde(default)]
    pub end_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct WorkspaceSharedAuditExportJobRecord {
    pub id: Uuid,
    pub numeric_task_id: i64,
    pub status: String,
    pub workspace_id: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub error_message: Option<String>,
    pub file_name: Option<String>,
    pub content_type: Option<String>,
    pub byte_size: Option<i64>,
    pub download_ready: bool,
}

#[derive(Debug, Clone, Deserialize, Default, IntoParams, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[into_params(parameter_in = Query)]
pub struct ListWorkspaceContentComplianceClearedTemplateAuditExportsQuery {
    #[serde(default)]
    pub format: Option<String>,
    /// Filter exports with `exported_at >=` this instant (RFC3339).
    #[serde(default)]
    pub exported_start_at: Option<String>,
    /// Filter exports with `exported_at <=` this instant (RFC3339).
    #[serde(default)]
    pub exported_end_at: Option<String>,
    #[serde(default)]
    pub limit: Option<i64>,
    #[serde(default)]
    pub offset: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
#[schema(rename_all = "camelCase")]
pub struct ListWorkspaceContentComplianceClearedTemplateAuditExportsResponse {
    pub workspace_id: Uuid,
    pub can_manage: bool,
    pub items: Vec<WorkspaceContentComplianceClearedTemplateAuditExportRecord>,
    pub has_more: bool,
    pub next_offset: Option<i64>,
}

impl Default for NotificationPreferences {
    fn default() -> Self {
        Self {
            muted_notification_types: Vec::new(),
            muted_workspace_ids: Vec::new(),
            muted_project_ids: Vec::new(),
            deliver_critical_even_muted: true,
            content_compliance_cleared_throttle_minutes:
                default_content_compliance_cleared_throttle_minutes(),
            content_compliance_cleared_stage_throttle_minutes: HashMap::new(),
            content_compliance_cleared_templates: Vec::new(),
            content_compliance_cleared_template_order: Vec::new(),
            content_compliance_cleared_recent_template_ids: Vec::new(),
        }
    }
}
