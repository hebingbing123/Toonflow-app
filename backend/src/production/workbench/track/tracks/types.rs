//! 工作台视频轨添加 / 删除请求与响应。

use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct AddTrackBody {
    pub(crate) project_id: i32,
    pub(crate) script_id: i32,
    pub(crate) track_name: String,
    #[serde(default)]
    #[allow(dead_code)]
    pub(crate) track_type: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct AddTrackResponse {
    pub(crate) track_id: i32,
    pub(crate) track_name: String,
    pub(crate) message: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct DeleteTrackBody {
    pub(crate) project_id: i32,
    pub(crate) script_id: i32,
    pub(crate) track_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct DeleteTrackResponse {
    pub(crate) track_id: i32,
    pub(crate) message: &'static str,
}
