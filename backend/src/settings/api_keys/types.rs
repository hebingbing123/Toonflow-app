use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ApiKeyScopeDto {
    ReadOnly,
    ReadWrite,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ApiKeyStatusDto {
    Active,
    Revoked,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ApiKeyRecord {
    pub id: Uuid,
    pub public_id: String,
    pub display_name: String,
    pub scope: ApiKeyScopeDto,
    pub status: ApiKeyStatusDto,
    pub key_hint: String,
    pub expires_at: Option<DateTime<Utc>>,
    pub revoked_at: Option<DateTime<Utc>>,
    pub rotated_at: Option<DateTime<Utc>>,
    pub last_used_at: Option<DateTime<Utc>>,
    pub last_used_path: Option<String>,
    pub last_used_method: Option<String>,
    pub last_used_ip: Option<String>,
    pub last_used_user_agent: Option<String>,
    pub use_count: i64,
    pub is_expired: bool,
    pub is_usable: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ApiKeyAuditRecord {
    pub id: Uuid,
    pub api_key_id: Uuid,
    pub event_type: String,
    pub event_summary: String,
    pub metadata: serde_json::Value,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ApiKeyListResponse {
    pub items: Vec<ApiKeyRecord>,
    pub active_count: usize,
    pub revoked_count: usize,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ApiKeyAuditListResponse {
    pub items: Vec<ApiKeyAuditRecord>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ApiKeyCreatedResponse {
    pub record: ApiKeyRecord,
    pub plaintext_token: String,
}

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ApiKeyCreateBody {
    pub display_name: String,
    pub scope: ApiKeyScopeDto,
    #[serde(default)]
    pub expires_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ApiKeyRevokeBody {
    #[serde(default)]
    pub reason: Option<String>,
}

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ApiKeyRotateBody {
    #[serde(default)]
    pub expires_at_action: Option<ApiKeyExpiresAtActionDto>,
    #[serde(default)]
    pub expires_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ApiKeyExpiresAtActionDto {
    Preserve,
    Clear,
    Set,
}

#[derive(Debug, Clone, Deserialize, IntoParams, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ApiKeyAuditQuery {
    #[serde(default)]
    pub limit: Option<i64>,
}
