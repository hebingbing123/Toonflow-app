use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
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

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct ApplyNotificationPreferencesTemplateBody {
    pub template: String,
}

impl Default for NotificationPreferences {
    fn default() -> Self {
        Self {
            muted_notification_types: Vec::new(),
            muted_workspace_ids: Vec::new(),
            muted_project_ids: Vec::new(),
            deliver_critical_even_muted: true,
        }
    }
}
