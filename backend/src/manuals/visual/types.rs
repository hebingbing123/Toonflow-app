use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize)]
pub struct VisualManualEntry {
    pub label: String,
    pub value: String,
    pub data: String,
}

#[derive(Debug, Serialize)]
pub struct VisualManualStyle {
    /// First line of **`README.md`** (Electron client strips **`--`**).
    pub name: String,
    /// Relative paths under **`data/skills`**, e.g. **`art_skills/{style}/images/a.png`**.
    pub image: Vec<String>,
    #[serde(rename = "stylePath")]
    pub style_path: String,
    /// Same shape as Electron-era **`data`** array.
    pub data: Vec<VisualManualEntry>,
}

#[derive(Debug, Serialize)]
pub struct VisualManualResponse {
    pub styles: Vec<VisualManualStyle>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct VisualManualDataItem {
    #[allow(dead_code)]
    pub(super) label: String,
    pub(super) value: String,
    pub(super) data: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct AddVisualManualBody {
    pub(super) name: String,
    pub(super) images: Vec<String>,
    pub(super) style_path: String,
    pub(super) data: Vec<VisualManualDataItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct EditVisualManualBody {
    pub(super) name: String,
    pub(super) style_path: String,
    pub(super) images: Vec<String>,
    pub(super) data: Vec<VisualManualDataItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct DeleteVisualManualBody {
    pub(super) name: String,
}

#[derive(Debug, Serialize)]
pub(super) struct EmptyOkObject {}

#[derive(Debug, Serialize)]
pub(super) struct DeleteVisualManualResponse {
    pub(super) message: &'static str,
}
