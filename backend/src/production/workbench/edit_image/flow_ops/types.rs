use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct ImageFlowResponse {
    pub flow_id: String,
    pub steps: Vec<ImageFlowStep>,
    pub default_model: String,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct ImageFlowStep {
    pub step_id: String,
    pub step_name: String,
    pub status: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct ImageDefaultModelResponse {
    pub model: String,
    pub resolution: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct SaveImageFlowBody {
    pub flow_id: String,
    #[allow(dead_code)]
    pub steps: Vec<ImageFlowStepInput>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct ImageFlowStepInput {
    #[allow(dead_code)]
    pub step_id: String,
    #[allow(dead_code)]
    pub status: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct SaveImageFlowResponse {
    pub flow_id: String,
    pub saved: bool,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct UpdateImageFlowBody {
    pub flow_id: String,
    pub step_id: String,
    #[allow(dead_code)]
    pub updates: serde_json::Value,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct UpdateImageFlowResponse {
    pub flow_id: String,
    pub step_id: String,
    pub updated: bool,
}
