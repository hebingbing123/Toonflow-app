use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq)]
pub(in crate::production::workbench::storyboard) struct StoryboardInsertDraft {
    pub(in crate::production::workbench::storyboard) prompt: String,
    pub(in crate::production::workbench::storyboard) duration: i32,
}

#[derive(Debug)]
pub(in crate::production::workbench::storyboard) struct StoryboardPreviewData {
    pub(in crate::production::workbench::storyboard) file_path: Option<String>,
    pub(in crate::production::workbench::storyboard) prompt: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct StoryboardScopeBody {
    #[serde(default)]
    pub(in crate::production::workbench::storyboard) project_id: Option<i32>,
    #[serde(default)]
    pub(in crate::production::workbench::storyboard) project_uuid: Option<Uuid>,
    pub(in crate::production::workbench::storyboard) script_id: i32,
    pub(in crate::production::workbench::storyboard) storyboard_id: i32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct StoryboardScriptScopeBody {
    #[serde(default)]
    pub(in crate::production::workbench::storyboard) project_id: Option<i32>,
    #[serde(default)]
    pub(in crate::production::workbench::storyboard) project_uuid: Option<Uuid>,
    pub(in crate::production::workbench::storyboard) script_id: i32,
    /// When set and matches server **`data_version`**, response returns **`unchanged: true`** with empty **`data`**.
    #[serde(default)]
    pub(in crate::production::workbench::storyboard) client_data_version: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct DownPreviewImageResponse {
    pub(in crate::production::workbench::storyboard) storyboard_id: i32,
    pub(in crate::production::workbench::storyboard) preview_url: Option<String>,
    pub(in crate::production::workbench::storyboard) message: &'static str,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct PreviewImageResponse {
    pub(in crate::production::workbench::storyboard) storyboard_id: i32,
    pub(in crate::production::workbench::storyboard) image_url: Option<String>,
    pub(in crate::production::workbench::storyboard) prompt: Option<String>,
}
