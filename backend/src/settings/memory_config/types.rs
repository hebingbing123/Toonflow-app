use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize)]
pub(crate) struct MemoryConfigSavedResponse {
    pub(super) message: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct ClearAgentMemoriesSettingsBody {
    pub(super) project_id: i32,
    pub(super) agent_type: String,
    #[serde(default)]
    pub(super) episodes_id: Option<i32>,
}
