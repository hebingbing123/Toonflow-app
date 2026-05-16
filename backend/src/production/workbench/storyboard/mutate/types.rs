//! 分镜编辑 / 删帧 / 更新 URL 的请求与响应类型。

use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct EditStoryboardInfoBody {
    #[serde(default)]
    pub(crate) project_id: Option<i32>,
    #[serde(default)]
    pub(crate) project_uuid: Option<Uuid>,
    pub(crate) script_id: i32,
    pub(crate) storyboard_id: i32,
    pub(crate) prompt: String,
    #[serde(default)]
    pub(crate) duration: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct EditStoryboardInfoResponse {
    pub(crate) storyboard_id: i32,
    pub(crate) message: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct RemoveFrameBody {
    #[serde(default)]
    pub(crate) project_id: Option<i32>,
    #[serde(default)]
    pub(crate) project_uuid: Option<Uuid>,
    pub(crate) script_id: i32,
    pub(crate) storyboard_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct RemoveFrameResponse {
    pub(crate) storyboard_id: i32,
    pub(crate) message: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct UpdateStoryboardUrlBody {
    #[serde(default)]
    pub(crate) project_id: Option<i32>,
    #[serde(default)]
    pub(crate) project_uuid: Option<Uuid>,
    pub(crate) script_id: i32,
    pub(crate) storyboard_id: i32,
    pub(crate) image_url: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct UpdateStoryboardUrlResponse {
    pub(crate) storyboard_id: i32,
    pub(crate) image_url: String,
    pub(crate) message: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct UpdateStoryboardLiveActionReferenceBody {
    #[serde(default)]
    pub(crate) project_id: Option<i32>,
    #[serde(default)]
    pub(crate) project_uuid: Option<Uuid>,
    pub(crate) script_id: i32,
    pub(crate) storyboard_id: i32,
    #[serde(default)]
    pub(crate) reference_shot_urls: Vec<String>,
    #[serde(default)]
    pub(crate) performance_notes: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct UpdateStoryboardLiveActionReferenceResponse {
    pub(crate) storyboard_id: i32,
    pub(crate) reference_shot_urls: Vec<String>,
    pub(crate) performance_notes: Option<String>,
    pub(crate) message: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct UpdateStoryboardDurationBody {
    #[serde(default)]
    pub(crate) project_id: Option<i32>,
    #[serde(default)]
    pub(crate) project_uuid: Option<Uuid>,
    pub(crate) script_id: i32,
    pub(crate) storyboard_id: i32,
    pub(crate) duration: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct UpdateStoryboardDurationResponse {
    pub(crate) storyboard_id: i32,
    pub(crate) duration: i32,
    pub(crate) message: &'static str,
}
