use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

const fn default_enabled() -> bool {
    true
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct PlatformConfigToggleSet {
    #[serde(default = "default_enabled")]
    pub help_hub_enabled: bool,
    #[serde(default = "default_enabled")]
    pub quality_dashboard_enabled: bool,
    #[serde(default = "default_enabled")]
    pub quality_refresh_controls_enabled: bool,
    #[serde(default = "default_enabled")]
    pub platform_status_enabled: bool,
    #[serde(default = "default_enabled")]
    pub workspace_activity_enabled: bool,
    #[serde(default = "default_enabled")]
    pub benchmark_pane_enabled: bool,
    #[serde(default = "default_enabled")]
    pub jobs_pane_enabled: bool,
}

impl PlatformConfigToggleSet {
    pub fn default_seeded() -> Self {
        Self {
            help_hub_enabled: true,
            quality_dashboard_enabled: true,
            quality_refresh_controls_enabled: true,
            platform_status_enabled: true,
            workspace_activity_enabled: true,
            benchmark_pane_enabled: true,
            jobs_pane_enabled: true,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct PlatformConfigResponse {
    pub scope: String,
    pub schema_version: i32,
    pub effective: PlatformConfigToggleSet,
    pub plan_tier: String,
    pub plan_override: Option<PlatformConfigToggleSet>,
    pub has_plan_override: bool,
    pub user_override: PlatformConfigToggleSet,
    pub has_user_override: bool,
    pub workspace_override: Option<PlatformConfigToggleSet>,
    pub has_workspace_override: bool,
    pub current_workspace: Option<PlatformConfigWorkspaceContext>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct PlatformConfigEnvelope {
    pub toggles: Option<PlatformConfigToggleSet>,
    pub scope: Option<String>,
    pub reset: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[schema(rename_all = "camelCase")]
pub struct PlatformConfigWorkspaceContext {
    pub id: uuid::Uuid,
    pub name: String,
    pub workspace_type: String,
    pub role: String,
    pub can_manage_override: bool,
}
