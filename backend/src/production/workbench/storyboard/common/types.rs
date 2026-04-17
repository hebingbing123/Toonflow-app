use serde::{Deserialize, Serialize};

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
    pub(in crate::production::workbench::storyboard) project_id: i32,
    pub(in crate::production::workbench::storyboard) script_id: i32,
    pub(in crate::production::workbench::storyboard) storyboard_id: i32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct StoryboardScriptScopeBody {
    pub(in crate::production::workbench::storyboard) project_id: i32,
    pub(in crate::production::workbench::storyboard) script_id: i32,
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
