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
