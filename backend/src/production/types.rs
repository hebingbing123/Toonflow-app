//! 制作域共享类型（视频列表、工作台生成视频请求体等）。

use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct GenerateVideoUploadItem {
    pub(crate) id: i32,
    pub(crate) sources: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct WorkbenchGenerateVideoBody {
    pub(crate) project_id: i32,
    pub(crate) script_id: i32,
    pub(crate) upload_data: Vec<GenerateVideoUploadItem>,
    pub(crate) prompt: String,
    #[serde(default)]
    pub(crate) negative_prompt: Option<String>,
    pub(crate) model: String,
    pub(crate) mode: String,
    pub(crate) resolution: String,
    pub(crate) duration: i32,
    #[serde(default)]
    pub(crate) audio: Option<bool>,
    pub(crate) track_id: i32,
}

// =============================================================================
// Video List (Wave E)
// =============================================================================

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(crate) struct VideoItem {
    pub(crate) id: i32,
    pub(crate) script_id: Option<i32>,
    pub(crate) prompt: Option<String>,
    pub(crate) video_url: Option<String>,
    pub(crate) duration: Option<String>,
    pub(crate) state: Option<String>,
    pub(crate) track_id: Option<i32>,
    pub(crate) created_at: Option<chrono::DateTime<chrono::Utc>>,
}
