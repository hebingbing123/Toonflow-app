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
    pub automation_mode: String,
    pub title_max_chars: i32,
    pub requires_cover: bool,
    pub notes: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PublishPlatformMatrixResponse {
    pub platforms: Vec<PublishPlatformCapabilityRow>,
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

#[derive(Debug, FromRow)]
pub(crate) struct PublishTargetRow {
    pub(crate) id: Uuid,
    pub(crate) draft_id: Uuid,
    pub(crate) platform_id: String,
    pub(crate) automation_mode: String,
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
