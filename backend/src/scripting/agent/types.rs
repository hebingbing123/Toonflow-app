use serde::{Deserialize, Serialize};
use serde_json::Value;

// Same advisory lock family as [`crate::scripting::scripts`] for allocating
// **`app_script.numeric_id`**.
pub(super) const ADV_LOCK_SCRIPT_NUMERIC_ID: i64 = 884_422_002;
pub(super) const MAX_PLAN_SCRIPT_ROWS: usize = 200;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) enum ScriptAgentKind {
    #[serde(rename = "scriptAgent")]
    ScriptAgent,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct GetScriptAgentPlanBody {
    pub(super) project_id: i32,
    pub(super) agent_type: ScriptAgentKind,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct SetPlanScriptRow {
    pub(super) name: String,
    pub(super) content: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct SetScriptAgentPlanData {
    pub(super) story_skeleton: String,
    pub(super) adaptation_strategy: String,
    #[serde(default)]
    pub(super) script: Vec<SetPlanScriptRow>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct SetScriptAgentPlanBody {
    pub(super) project_id: i32,
    pub(super) agent_type: ScriptAgentKind,
    pub(super) data: SetScriptAgentPlanData,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct UpdateScriptRow {
    pub(super) id: i32,
    pub(super) content: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct UpdateScriptAgentDataPayload {
    pub(super) story_skeleton: String,
    pub(super) adaptation_strategy: String,
    pub(super) script: Vec<UpdateScriptRow>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct UpdateScriptAgentDataBody {
    pub(super) id: i64,
    pub(super) data: UpdateScriptAgentDataPayload,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct CodeDataEnvelope<T: Serialize> {
    pub(super) code: i32,
    pub(super) data: T,
    pub(super) message: &'static str,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct PlanFlatData {
    pub(super) story_skeleton: String,
    pub(super) adaptation_strategy: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct PlanDataWithId {
    pub(super) data: Value,
    pub(super) id: i64,
}
