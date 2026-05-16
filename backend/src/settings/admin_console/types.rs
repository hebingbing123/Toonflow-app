use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

#[derive(Debug, Clone, serde::Deserialize, IntoParams, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct AdminSearchQuery {
    pub q: String,
    #[serde(default)]
    pub limit: Option<i64>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminSearchResponse {
    pub query: String,
    pub users: Vec<AdminUserSearchHit>,
    pub workspaces: Vec<AdminWorkspaceSearchHit>,
    pub projects: Vec<AdminProjectSearchHit>,
    pub jobs: Vec<AdminJobSearchHit>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminUserSearchHit {
    pub user_id: Uuid,
    pub email: Option<String>,
    pub plan_tier: Option<String>,
    pub operational_status: String,
    pub current_workspace_id: Option<Uuid>,
    pub workspace_count: i64,
    pub project_count: i64,
    pub active_job_count: i64,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminWorkspaceSearchHit {
    pub workspace_id: Uuid,
    pub name: String,
    pub workspace_type: String,
    pub archived_at: Option<DateTime<Utc>>,
    pub owner_user_id: Uuid,
    pub owner_email: Option<String>,
    pub member_count: i64,
    pub project_count: i64,
    pub active_job_count: i64,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminProjectSearchHit {
    pub project_id: Uuid,
    pub numeric_id: i32,
    pub name: Option<String>,
    pub workspace_id: Option<Uuid>,
    pub workspace_name: Option<String>,
    pub owner_user_id: Uuid,
    pub owner_email: Option<String>,
    pub archived_at: Option<DateTime<Utc>>,
    pub updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminJobSearchHit {
    pub job_id: Uuid,
    pub owner_user_id: Uuid,
    pub owner_email: Option<String>,
    pub kind: String,
    pub status: String,
    pub project_id: Option<Uuid>,
    pub project_numeric_id: Option<i32>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminWorkspaceMemberSummary {
    pub user_id: Uuid,
    pub email: Option<String>,
    pub role: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminProjectSummary {
    pub project_id: Uuid,
    pub numeric_id: i32,
    pub name: Option<String>,
    pub owner_user_id: Uuid,
    pub owner_email: Option<String>,
    pub updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminJobSummary {
    pub job_id: Uuid,
    pub owner_user_id: Uuid,
    pub owner_email: Option<String>,
    pub kind: String,
    pub status: String,
    pub project_id: Option<Uuid>,
    pub project_numeric_id: Option<i32>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminUserMembershipSummary {
    pub workspace_id: Uuid,
    pub workspace_name: String,
    pub workspace_type: String,
    pub role: String,
    pub archived_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminWorkspaceRef {
    pub workspace_id: Uuid,
    pub name: String,
    pub workspace_type: String,
    pub archived_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminUserDetailResponse {
    pub user_id: Uuid,
    pub email: Option<String>,
    pub created_at: DateTime<Utc>,
    pub plan_tier: String,
    pub operational_status: String,
    pub operational_status_reason: Option<String>,
    pub ops_note: Option<String>,
    pub daily_job_quota_override: Option<i64>,
    pub billing_provider: Option<String>,
    pub subscription_status: Option<String>,
    pub current_workspace: Option<AdminWorkspaceRef>,
    pub workspace_count: i64,
    pub project_count: i64,
    pub active_job_count: i64,
    pub api_key_count: i64,
    pub unread_notification_count: i64,
    pub memberships: Vec<AdminUserMembershipSummary>,
    pub recent_jobs: Vec<AdminJobSummary>,
    pub governance_audit: Vec<AdminUserGovernanceAuditSummary>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminUserGovernanceAuditSummary {
    pub audit_id: Uuid,
    pub actor_label: String,
    pub created_at: DateTime<Utc>,
    pub previous_state: serde_json::Value,
    pub next_state: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminWorkspaceGovernanceAuditSummary {
    pub audit_id: Uuid,
    pub actor_label: String,
    pub created_at: DateTime<Utc>,
    pub previous_state: serde_json::Value,
    pub next_state: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminWorkspaceProjectAclSummary {
    pub project_id: Uuid,
    pub numeric_id: i32,
    pub name: Option<String>,
    pub owner_user_id: Uuid,
    pub owner_email: Option<String>,
    pub archived_at: Option<DateTime<Utc>>,
    pub acl_mode: String,
    pub explicit_acl_count: i64,
    pub editor_count: i64,
    pub viewer_count: i64,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminWorkspaceDetailResponse {
    pub workspace_id: Uuid,
    pub name: String,
    pub workspace_type: String,
    pub owner_user_id: Uuid,
    pub owner_email: Option<String>,
    pub archived_at: Option<DateTime<Utc>>,
    pub ops_note: Option<String>,
    pub member_count: i64,
    pub project_count: i64,
    pub active_job_count: i64,
    pub members: Vec<AdminWorkspaceMemberSummary>,
    pub workspace_role_breakdown: serde_json::Value,
    pub project_acl_summaries: Vec<AdminWorkspaceProjectAclSummary>,
    pub recent_projects: Vec<AdminProjectSummary>,
    pub recent_jobs: Vec<AdminJobSummary>,
    pub governance_audit: Vec<AdminWorkspaceGovernanceAuditSummary>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminProjectGovernanceAuditSummary {
    pub audit_id: Uuid,
    pub actor_label: String,
    pub created_at: DateTime<Utc>,
    pub previous_state: serde_json::Value,
    pub next_state: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminProjectAclMemberSummary {
    pub user_id: Uuid,
    pub email: Option<String>,
    pub workspace_role: String,
    pub project_role: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminProjectWorkspaceMemberCandidateSummary {
    pub user_id: Uuid,
    pub email: Option<String>,
    pub workspace_role: String,
    pub explicit_project_role: Option<String>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminProjectDetailResponse {
    pub project_id: Uuid,
    pub numeric_id: i32,
    pub name: Option<String>,
    pub owner_user_id: Uuid,
    pub owner_email: Option<String>,
    pub workspace: Option<AdminWorkspaceRef>,
    pub archived_at: Option<DateTime<Utc>>,
    pub ops_note: Option<String>,
    pub created_at: Option<DateTime<Utc>>,
    pub updated_at: Option<DateTime<Utc>>,
    pub script_count: i64,
    pub asset_count: i64,
    pub job_count: i64,
    pub active_job_count: i64,
    pub project_acl_mode: String,
    pub explicit_acl_count: i64,
    pub editor_count: i64,
    pub viewer_count: i64,
    pub acl_members: Vec<AdminProjectAclMemberSummary>,
    pub workspace_member_candidates: Vec<AdminProjectWorkspaceMemberCandidateSummary>,
    pub recent_jobs: Vec<AdminJobSummary>,
    pub governance_audit: Vec<AdminProjectGovernanceAuditSummary>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AdminOperationalStatusDto {
    Active,
    Suspended,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AdminQuotaOverrideActionDto {
    Preserve,
    Clear,
    Set,
}

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct AdminUserGovernanceUpdateBody {
    pub operational_status: AdminOperationalStatusDto,
    #[serde(default)]
    pub operational_status_reason: Option<String>,
    #[serde(default)]
    pub ops_note: Option<String>,
    #[serde(default)]
    pub daily_job_quota_action: Option<AdminQuotaOverrideActionDto>,
    #[serde(default)]
    pub daily_job_quota: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AdminUserWorkspaceContextActionDto {
    ResetToPersonal,
    SetToWorkspace,
}

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct AdminUserWorkspaceContextUpdateBody {
    pub action: AdminUserWorkspaceContextActionDto,
    #[serde(default)]
    pub workspace_id: Option<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema, PartialEq, Eq, Default)]
#[serde(rename_all = "snake_case")]
pub enum AdminWorkspaceLifecycleActionDto {
    #[default]
    Preserve,
    Archive,
    Restore,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema, PartialEq, Eq, Default)]
#[serde(rename_all = "snake_case")]
pub enum AdminWorkspaceOpsNoteActionDto {
    #[default]
    Preserve,
    Set,
    Clear,
}

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct AdminWorkspaceGovernanceUpdateBody {
    #[serde(default)]
    pub workspace_lifecycle: AdminWorkspaceLifecycleActionDto,
    #[serde(default)]
    pub ops_note_action: AdminWorkspaceOpsNoteActionDto,
    #[serde(default)]
    pub ops_note: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AdminWorkspaceMemberRemediationActionDto {
    Upsert,
    Remove,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AdminWorkspaceMemberRoleDto {
    Admin,
    Member,
}

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct AdminWorkspaceMemberRemediationBody {
    pub action: AdminWorkspaceMemberRemediationActionDto,
    pub user_id: Uuid,
    #[serde(default)]
    pub role: Option<AdminWorkspaceMemberRoleDto>,
}

/// Request body for internal owner transfer; only built via JSON deserialization.
#[allow(dead_code)]
#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct AdminWorkspaceOwnerTransferBody {
    pub target_user_id: Uuid,
}

pub type AdminProjectLifecycleActionDto = AdminWorkspaceLifecycleActionDto;
pub type AdminProjectOpsNoteActionDto = AdminWorkspaceOpsNoteActionDto;

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct AdminProjectGovernanceUpdateBody {
    #[serde(default)]
    pub project_lifecycle: AdminProjectLifecycleActionDto,
    #[serde(default)]
    pub ops_note_action: AdminProjectOpsNoteActionDto,
    #[serde(default)]
    pub ops_note: Option<String>,
}

/// Request body for internal project owner transfer; only built via JSON deserialization.
#[allow(dead_code)]
#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct AdminProjectOwnerTransferBody {
    pub target_user_id: Uuid,
}

/// Batch project governance (internal); wired when REST handler is added.
#[allow(dead_code)]
#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct AdminProjectBatchGovernanceUpdateBody {
    pub project_ids: Vec<Uuid>,
    #[serde(default)]
    pub project_lifecycle: AdminProjectLifecycleActionDto,
    #[serde(default)]
    pub ops_note_action: AdminProjectOpsNoteActionDto,
    #[serde(default)]
    pub ops_note: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminProjectBatchGovernanceResponse {
    pub requested_count: i64,
    pub updated_count: i64,
    pub projects: Vec<AdminProjectDetailResponse>,
}

/// Workspace billing query response (Task 8.1).
#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminWorkspaceBillingResponse {
    pub workspace_id: Uuid,
    pub workspace_name: String,
    pub workspace_type: String,
    pub owner_user_id: Uuid,
    pub owner_email: Option<String>,
    pub plan_tier: Option<String>,
    pub billing_currency: Option<String>,
    pub billing_provider: Option<String>,
    pub daily_job_quota: Option<i64>,
    pub jobs_today: i64,
    pub jobs_this_month: i64,
    pub member_count: i64,
    pub project_count: i64,
    pub created_at: DateTime<Utc>,
}

/// Query parameters for workspace billing list (Task 8.1).
#[derive(Debug, Clone, Deserialize, IntoParams, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct AdminWorkspaceBillingQuery {
    #[serde(default)]
    pub workspace_id: Option<Uuid>,
    #[serde(default)]
    pub limit: Option<i64>,
    #[serde(default)]
    pub offset: Option<i64>,
}
