//! HTTP + persistence types for the publish domain (short-video-space §E).

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::types::Json;
use sqlx::FromRow;
use utoipa::ToSchema;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishProfileResponse {
    pub id: Uuid,
    pub project_id: Uuid,
    pub name: String,
    pub target_market: Option<String>,
    pub default_platforms: Option<Vec<String>>,
    pub title_style: Option<String>,
    pub tag_strategy: Option<String>,
    pub bio_template: Option<String>,
    pub schedule_strategy: Option<String>,
    pub metadata: Value,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct CreatePublishProfileBody {
    #[serde(default = "default_profile_name")]
    pub name: String,
    pub target_market: Option<String>,
    pub default_platforms: Option<Vec<String>>,
    pub title_style: Option<String>,
    pub tag_strategy: Option<String>,
    pub bio_template: Option<String>,
    pub schedule_strategy: Option<String>,
    #[serde(default)]
    pub metadata: Value,
}

fn default_profile_name() -> String {
    "default".to_string()
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PatchPublishProfileBody {
    pub name: Option<String>,
    pub target_market: Option<String>,
    pub default_platforms: Option<Vec<String>>,
    pub title_style: Option<String>,
    pub tag_strategy: Option<String>,
    pub bio_template: Option<String>,
    pub schedule_strategy: Option<String>,
    pub metadata: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishDraftResponse {
    pub id: Uuid,
    pub project_id: Uuid,
    pub profile_id: Option<Uuid>,
    pub script_id: Option<Uuid>,
    pub video_asset_key: Option<String>,
    pub cover_asset_key: Option<String>,
    pub title: String,
    pub description: String,
    pub tags: Vec<String>,
    pub platform_copy: Value,
    pub scheduled_at: Option<DateTime<Utc>>,
    pub draft_status: String,
    pub metadata: Value,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct CreatePublishDraftBody {
    pub profile_id: Option<Uuid>,
    pub script_id: Option<Uuid>,
    #[serde(default)]
    pub video_asset_key: Option<String>,
    #[serde(default)]
    pub cover_asset_key: Option<String>,
    #[serde(default)]
    pub title: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub platform_copy: Value,
    pub scheduled_at: Option<DateTime<Utc>>,
    #[serde(default = "default_draft_editing")]
    pub draft_status: String,
    #[serde(default)]
    pub metadata: Value,
}

fn default_draft_editing() -> String {
    "editing".to_string()
}

/// Optional window for `GET …/publish/drafts`: only rows with `scheduled_at` in
/// `[scheduled_from, scheduled_to)` (RFC3339, UTC recommended).
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct ListPublishDraftsQuery {
    pub scheduled_from: Option<String>,
    pub scheduled_to: Option<String>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PatchPublishDraftBody {
    pub profile_id: Option<Uuid>,
    pub script_id: Option<Uuid>,
    pub video_asset_key: Option<String>,
    pub cover_asset_key: Option<String>,
    pub title: Option<String>,
    pub description: Option<String>,
    pub tags: Option<Vec<String>>,
    pub platform_copy: Option<Value>,
    pub scheduled_at: Option<DateTime<Utc>>,
    pub draft_status: Option<String>,
    pub metadata: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishTargetResponse {
    pub id: Uuid,
    pub draft_id: Uuid,
    pub platform_id: String,
    pub automation_mode: String,
    pub serial_order: i32,
    pub extra: Value,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize, Serialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct UpsertPublishTargetsBody {
    pub targets: Vec<PublishTargetInput>,
}

#[derive(Debug, Deserialize, Serialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishTargetInput {
    pub platform_id: String,
    pub automation_mode: String,
    /// Lower runs first for serial multi-platform publishes (**F3**).
    #[serde(default)]
    pub serial_order: i32,
    #[serde(default)]
    pub extra: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishJobResponse {
    pub id: Uuid,
    pub project_id: Uuid,
    pub draft_id: Uuid,
    pub status: String,
    pub semi_auto_ack_at: Option<DateTime<Utc>>,
    pub payload: Value,
    pub error_message: Option<String>,
    pub error_details: Option<Value>,
    pub claimed_by: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct CreatePublishJobBody {
    #[serde(default)]
    pub payload: Value,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct ListPublishAuditQuery {
    pub draft_id: Option<Uuid>,
    pub job_id: Option<Uuid>,
    pub delivery_mode: Option<String>,
    pub evidence_key: Option<String>,
    #[serde(default = "default_publish_audit_limit")]
    pub limit: i64,
}

fn default_publish_audit_limit() -> i64 {
    50
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct ListPublishPerformanceAlertsQuery {
    #[serde(default = "default_perf_alert_views_lt")]
    pub views_lt: i64,
    #[serde(default = "default_perf_alert_completion_rate_lt")]
    pub completion_rate_lt: f64,
    #[serde(default = "default_perf_alert_limit")]
    pub limit: i64,
}

fn default_perf_alert_views_lt() -> i64 {
    1000
}

fn default_perf_alert_completion_rate_lt() -> f64 {
    0.45
}

fn default_perf_alert_limit() -> i64 {
    50
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishPerformanceAlertResponse {
    pub target_id: Uuid,
    pub draft_id: Uuid,
    pub platform_id: String,
    pub views: i64,
    pub likes: i64,
    pub comments: i64,
    pub shares: i64,
    pub completion_rate: f64,
    pub synced_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishAttemptAuditResponse {
    pub id: Uuid,
    pub job_id: Uuid,
    pub draft_id: Uuid,
    pub target_id: Uuid,
    pub platform_id: String,
    pub attempt_no: i32,
    pub status: String,
    pub detail: Value,
    pub error_message: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishPrepareIssue {
    pub code: String,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub platform_id: Option<String>,
    pub severity: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishPrepareCheckResponse {
    pub draft_id: Uuid,
    pub ok: bool,
    pub issues: Vec<PublishPrepareIssue>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishPlatformCapabilityRow {
    pub platform_id: String,
    pub label_zh: String,
    /// `domestic` | `overseas`（**F4** 分区矩阵）.
    pub market_region: String,
    pub automation_mode: String,
    pub title_max_chars: i32,
    pub tags_max: i32,
    pub description_max_chars: i32,
    pub requires_cover: bool,
    pub notes: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishPlatformMatrixResponse {
    pub platforms: Vec<PublishPlatformCapabilityRow>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishValidateCopyBody {
    pub platform_copy: Value,
    pub targets: Vec<PublishTargetInput>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishValidateCopyResponse {
    pub ok: bool,
    pub issues: Vec<PublishPrepareIssue>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct SuggestPlatformCopyBody {
    #[serde(default)]
    pub apply: bool,
    pub style_hint: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct SuggestPlatformCopyResponse {
    pub draft_id: Uuid,
    pub platform_copy_fragment: Value,
    pub source: String,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct BatchScheduleDraftsBody {
    pub draft_ids: Vec<Uuid>,
    pub scheduled_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct BatchScheduleDraftsResponse {
    pub updated: i64,
}

#[derive(Debug, FromRow)]
pub(crate) struct PublishProfileRow {
    pub(crate) id: Uuid,
    pub(crate) project_id: Uuid,
    pub(crate) name: String,
    pub(crate) target_market: Option<String>,
    pub(crate) default_platforms: Option<Vec<String>>,
    pub(crate) title_style: Option<String>,
    pub(crate) tag_strategy: Option<String>,
    pub(crate) bio_template: Option<String>,
    pub(crate) schedule_strategy: Option<String>,
    pub(crate) metadata: Json<Value>,
    pub(crate) created_at: DateTime<Utc>,
    pub(crate) updated_at: DateTime<Utc>,
}

#[derive(Debug, FromRow)]
pub(crate) struct PublishDraftRow {
    pub(crate) id: Uuid,
    pub(crate) project_id: Uuid,
    pub(crate) profile_id: Option<Uuid>,
    pub(crate) script_id: Option<Uuid>,
    pub(crate) video_asset_key: Option<String>,
    pub(crate) cover_asset_key: Option<String>,
    pub(crate) title: String,
    pub(crate) description: String,
    pub(crate) tags: Vec<String>,
    pub(crate) platform_copy: Json<Value>,
    pub(crate) scheduled_at: Option<DateTime<Utc>>,
    pub(crate) draft_status: String,
    pub(crate) metadata: Json<Value>,
    pub(crate) created_at: DateTime<Utc>,
    pub(crate) updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, FromRow)]
pub(crate) struct PublishTargetRow {
    pub(crate) id: Uuid,
    pub(crate) draft_id: Uuid,
    pub(crate) platform_id: String,
    pub(crate) automation_mode: String,
    pub(crate) serial_order: i32,
    pub(crate) extra: Json<Value>,
    pub(crate) created_at: DateTime<Utc>,
    pub(crate) updated_at: DateTime<Utc>,
}

#[derive(Debug, FromRow)]
pub(crate) struct PublishJobRow {
    pub(crate) id: Uuid,
    pub(crate) project_id: Uuid,
    pub(crate) draft_id: Uuid,
    #[allow(dead_code)]
    pub(crate) owner_user_id: Uuid,
    pub(crate) status: String,
    pub(crate) semi_auto_ack_at: Option<DateTime<Utc>>,
    pub(crate) payload: Json<Value>,
    pub(crate) error_message: Option<String>,
    pub(crate) error_details: Option<Json<Value>>,
    pub(crate) claimed_by: Option<String>,
    pub(crate) created_at: DateTime<Utc>,
    pub(crate) updated_at: DateTime<Utc>,
}

#[derive(Debug, FromRow)]
pub(crate) struct PublishAttemptAuditRow {
    pub(crate) id: Uuid,
    pub(crate) job_id: Uuid,
    pub(crate) draft_id: Uuid,
    pub(crate) target_id: Uuid,
    pub(crate) platform_id: String,
    pub(crate) attempt_no: i32,
    pub(crate) status: String,
    pub(crate) detail: Json<Value>,
    pub(crate) error_message: Option<String>,
    pub(crate) created_at: DateTime<Utc>,
}

#[derive(Debug, FromRow)]
#[allow(dead_code)]
pub(crate) struct PublishMetricSyncCursorRow {
    pub(crate) id: Uuid,
    pub(crate) project_id: Uuid,
    pub(crate) target_id: Uuid,
    pub(crate) platform_id: String,
    pub(crate) cursor_token: Option<String>,
    pub(crate) status: String,
    pub(crate) retry_count: i32,
    pub(crate) next_retry_at: Option<DateTime<Utc>>,
    pub(crate) last_error: Option<String>,
    pub(crate) metadata: Json<Value>,
    pub(crate) last_synced_at: Option<DateTime<Utc>>,
    pub(crate) updated_at: DateTime<Utc>,
}

#[derive(Debug, FromRow)]
pub(crate) struct PublishPerformanceAlertRow {
    pub(crate) target_id: Uuid,
    pub(crate) draft_id: Uuid,
    pub(crate) platform_id: String,
    pub(crate) views: i64,
    pub(crate) likes: i64,
    pub(crate) comments: i64,
    pub(crate) shares: i64,
    pub(crate) completion_rate: f64,
    pub(crate) synced_at: DateTime<Utc>,
}

pub(crate) fn profile_from_row(r: PublishProfileRow) -> PublishProfileResponse {
    PublishProfileResponse {
        id: r.id,
        project_id: r.project_id,
        name: r.name,
        target_market: r.target_market,
        default_platforms: r.default_platforms,
        title_style: r.title_style,
        tag_strategy: r.tag_strategy,
        bio_template: r.bio_template,
        schedule_strategy: r.schedule_strategy,
        metadata: r.metadata.0,
        created_at: r.created_at,
        updated_at: r.updated_at,
    }
}

pub(crate) fn draft_from_row(r: PublishDraftRow) -> PublishDraftResponse {
    PublishDraftResponse {
        id: r.id,
        project_id: r.project_id,
        profile_id: r.profile_id,
        script_id: r.script_id,
        video_asset_key: r.video_asset_key,
        cover_asset_key: r.cover_asset_key,
        title: r.title,
        description: r.description,
        tags: r.tags,
        platform_copy: r.platform_copy.0,
        scheduled_at: r.scheduled_at,
        draft_status: r.draft_status,
        metadata: r.metadata.0,
        created_at: r.created_at,
        updated_at: r.updated_at,
    }
}

pub(crate) fn target_from_row(r: PublishTargetRow) -> PublishTargetResponse {
    PublishTargetResponse {
        id: r.id,
        draft_id: r.draft_id,
        platform_id: r.platform_id,
        automation_mode: r.automation_mode,
        serial_order: r.serial_order,
        extra: r.extra.0,
        created_at: r.created_at,
        updated_at: r.updated_at,
    }
}

pub(crate) fn job_from_row(r: PublishJobRow) -> PublishJobResponse {
    PublishJobResponse {
        id: r.id,
        project_id: r.project_id,
        draft_id: r.draft_id,
        status: r.status,
        semi_auto_ack_at: r.semi_auto_ack_at,
        payload: r.payload.0,
        error_message: r.error_message,
        error_details: r.error_details.map(|j| j.0),
        claimed_by: r.claimed_by,
        created_at: r.created_at,
        updated_at: r.updated_at,
    }
}

pub(crate) fn attempt_audit_from_row(r: PublishAttemptAuditRow) -> PublishAttemptAuditResponse {
    PublishAttemptAuditResponse {
        id: r.id,
        job_id: r.job_id,
        draft_id: r.draft_id,
        target_id: r.target_id,
        platform_id: r.platform_id,
        attempt_no: r.attempt_no,
        status: r.status,
        detail: r.detail.0,
        error_message: r.error_message,
        created_at: r.created_at,
    }
}

pub(crate) fn performance_alert_from_row(
    r: PublishPerformanceAlertRow,
) -> PublishPerformanceAlertResponse {
    PublishPerformanceAlertResponse {
        target_id: r.target_id,
        draft_id: r.draft_id,
        platform_id: r.platform_id,
        views: r.views,
        likes: r.likes,
        comments: r.comments,
        shares: r.shares,
        completion_rate: r.completion_rate,
        synced_at: r.synced_at,
    }
}

/// Aggregated response for short-video-space publish overview (J.4)
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishOverviewResponse {
    pub matrix: PublishPlatformMatrixResponse,
    pub drafts: Vec<PublishDraftResponse>,
    pub prepare_check: Option<PublishPrepareCheckResponse>,
    pub jobs: Vec<PublishJobResponse>,
    pub performance_alerts: Vec<PublishPerformanceAlertResponse>,
    pub audit: Vec<PublishAttemptAuditResponse>,
}

/// Query parameters for publish overview endpoint
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishOverviewQuery {
    /// Optional draft ID to fetch prepare check for
    pub draft_id: Option<Uuid>,
    /// Audit limit (default: 30)
    #[serde(default = "default_overview_audit_limit")]
    pub audit_limit: i64,
}

fn default_overview_audit_limit() -> i64 {
    30
}
