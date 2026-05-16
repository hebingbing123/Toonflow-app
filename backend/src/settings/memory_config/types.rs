use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Serialize)]
pub(crate) struct MemoryConfigSavedResponse {
    pub(super) message: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct ClearAgentMemoriesSettingsBody {
    #[serde(default)]
    pub(super) project_uuid: Option<Uuid>,
    #[serde(default)]
    pub(super) project_id: Option<i32>,
    pub(super) agent_type: String,
    #[serde(default)]
    pub(super) episodes_id: Option<i32>,
}
