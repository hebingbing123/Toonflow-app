use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize)]
pub struct SwitchAiDevToolResponse {
    pub value: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct SwitchAiDevToolPutBody {
    pub(super) value: String,
}
