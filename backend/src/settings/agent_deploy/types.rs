use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct AgentDeployListBody {}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct AgentDeployListItem {
    pub(super) id: i32,
    pub(super) model: String,
    pub(super) key: String,
    pub(super) model_name: String,
    pub(super) vendor_id: Option<String>,
    pub(super) desc: String,
    pub(super) name: String,
    pub(super) disabled: bool,
    pub(super) icon: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub(super) struct AgentDeployConfigItem {
    pub(super) model: String,
    pub(super) model_name: String,
    #[serde(default)]
    pub(super) vendor_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub(super) struct AgentDeployConfig {
    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    pub(super) rows: HashMap<String, AgentDeployConfigItem>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct AgentDeploySavedResponse {
    pub(super) key: String,
    pub(super) message: &'static str,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct AgentDeployKeyIgnoredResponse {
    pub(super) message: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct DeployAgentModelBody {
    pub(super) id: i32,
    pub(super) name: String,
    pub(super) model: String,
    pub(super) model_name: String,
    #[serde(default)]
    pub(super) vendor_id: Option<String>,
    pub(super) desc: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct AgentSetKeyBody {
    #[serde(default)]
    pub(super) key: Option<String>,
}
