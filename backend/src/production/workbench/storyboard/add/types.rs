//! 分镜「单条添加 / 批量添加」请求与响应类型。

use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct AddStoryboardBody {
    #[serde(default)]
    pub(crate) project_id: Option<i32>,
    #[serde(default)]
    pub(crate) project_uuid: Option<Uuid>,
    pub(crate) script_id: i32,
    pub(crate) prompt: String,
    #[serde(default)]
    pub(crate) duration: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct AddStoryboardResponse {
    pub(crate) storyboard_id: i32,
    pub(crate) message: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct BatchAddInfoBody {
    #[serde(default)]
    pub(crate) project_id: Option<i32>,
    #[serde(default)]
    pub(crate) project_uuid: Option<Uuid>,
    pub(crate) script_id: i32,
    pub(crate) storyboards: Vec<StoryboardInfoInput>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct StoryboardInfoInput {
    pub(crate) prompt: String,
    #[serde(default)]
    pub(crate) duration: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct BatchAddInfoResponse {
    pub(crate) added: usize,
    pub(crate) storyboard_ids: Vec<i32>,
}
