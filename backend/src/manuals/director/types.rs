use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy)]
pub(super) struct DirectorSlotDef {
    pub(super) label: &'static str,
    pub(super) value: &'static str,
    pub(super) sub_dir: Option<&'static str>,
}

/// Same three slots as Electron-era `addDirectorManual` / `queryDirectorManual`
/// (`driector_skills` spelling preserved).
pub(super) const DIRECTOR_SLOTS: [DirectorSlotDef; 3] = [
    DirectorSlotDef {
        label: "README",
        value: "README",
        sub_dir: None,
    },
    DirectorSlotDef {
        label: "导演规划",
        value: "director_planning_narrative",
        sub_dir: Some("driector_skills"),
    },
    DirectorSlotDef {
        label: "分镜表",
        value: "director_storyboard_table_narrative",
        sub_dir: Some("driector_skills"),
    },
];

#[derive(Debug, Serialize)]
pub struct DirectorManualSlotRow {
    pub label: String,
    pub value: String,
    pub data: String,
}

#[derive(Debug, Serialize)]
pub struct DirectorManualStyleRow {
    pub name: String,
    pub image: Vec<String>,
    /// Folder name under `story_skills/` (SQLite field `directorManual`).
    #[serde(rename = "directorManual")]
    pub director_manual_key: String,
    pub data: Vec<DirectorManualSlotRow>,
}

#[derive(Debug, Serialize)]
pub struct DirectorManualListResponse {
    pub data: Vec<DirectorManualStyleRow>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct DirectorManualDataItem {
    #[allow(dead_code)]
    pub label: String,
    pub value: String,
    pub data: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct AddDirectorManualBody {
    /// Display title used when writing `README` on `add` (Electron client did not prefix on add).
    pub name: String,
    pub images: Vec<String>,
    /// Target subdirectory under `story_skills/`.
    pub director_manual: String,
    pub data: Vec<DirectorManualDataItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct EditDirectorManualBody {
    pub name: String,
    pub director_manual: String,
    pub images: Vec<String>,
    pub data: Vec<DirectorManualDataItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct DeleteDirectorManualBody {
    /// Folder name under `story_skills/` (Electron-era `name`).
    pub name: String,
}
