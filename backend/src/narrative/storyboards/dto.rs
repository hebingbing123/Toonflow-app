//! 分镜 HTTP 类型和行映射。

use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow, Serialize)]
pub struct StoryboardRow {
    pub id: Uuid,
    pub script_id: Uuid,
    #[serde(rename = "numeric_id")]
    #[sqlx(rename = "numeric_id")]
    pub numeric_id: i32,
    #[serde(rename = "numeric_script_id")]
    #[sqlx(rename = "numeric_script_id")]
    pub numeric_script_id: Option<i32>,
    pub prompt: Option<String>,
    pub file_path: Option<String>,
    pub duration: Option<String>,
    pub state: Option<String>,
    pub track_id: Option<i32>,
    pub reason: Option<String>,
    pub track: Option<String>,
    pub video_desc: Option<String>,
    pub should_generate_image: Option<i32>,
    #[serde(rename = "numeric_project_id")]
    #[sqlx(rename = "numeric_project_id")]
    pub numeric_project_id: Option<i32>,
    pub flow_id: Option<i32>,
    pub sb_index: Option<i32>,
    pub create_time_ms: Option<i64>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct PatchStoryboardBody {
    #[serde(default)]
    pub(super) prompt: Option<Value>,
    #[serde(default)]
    pub(super) file_path: Option<Value>,
    #[serde(default)]
    pub(super) duration: Option<Value>,
    #[serde(default)]
    pub(super) state: Option<Value>,
    #[serde(default)]
    pub(super) reason: Option<Value>,
    #[serde(default)]
    pub(super) track: Option<Value>,
    #[serde(default)]
    pub(super) video_desc: Option<Value>,
    #[serde(default, rename = "numeric_script_id")]
    pub(super) numeric_script_id: Option<Value>,
    #[serde(default)]
    pub(super) track_id: Option<Value>,
    #[serde(default)]
    pub(super) should_generate_image: Option<Value>,
    #[serde(default, rename = "numeric_project_id")]
    pub(super) numeric_project_id: Option<Value>,
    #[serde(default)]
    pub(super) flow_id: Option<Value>,
    #[serde(default)]
    pub(super) sb_index: Option<Value>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct CreateStoryboardBody {
    #[serde(default)]
    pub(super) prompt: Option<String>,
    #[serde(default)]
    pub(super) file_path: Option<String>,
    #[serde(default)]
    pub(super) duration: Option<String>,
    #[serde(default)]
    pub(super) state: Option<String>,
    #[serde(default)]
    pub(super) track_id: Option<i32>,
    #[serde(default)]
    pub(super) reason: Option<String>,
    #[serde(default)]
    pub(super) track: Option<String>,
    #[serde(default)]
    pub(super) video_desc: Option<String>,
    #[serde(default)]
    pub(super) should_generate_image: Option<i32>,
    #[serde(default, rename = "numeric_script_id")]
    pub(super) numeric_script_id: Option<i32>,
    #[serde(default, rename = "numeric_project_id")]
    pub(super) numeric_project_id: Option<i32>,
    #[serde(default)]
    pub(super) flow_id: Option<i32>,
    #[serde(default)]
    pub(super) sb_index: Option<i32>,
}
