//! 项目范围的小说 HTTP 类型和行映射。

use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow, Serialize)]
pub struct NovelRow {
    pub id: Uuid,
    pub legacy_id: i32,
    pub chapter_index: i32,
    pub reel: Option<String>,
    pub chapter: String,
    pub chapter_data: String,
    pub event: Option<String>,
    pub event_state: i32,
    pub error_reason: Option<String>,
    pub create_time_ms: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct ListNovelsQuery {
    #[serde(default)]
    pub search: Option<String>,
    #[serde(default)]
    pub page: Option<u32>,
    #[serde(default)]
    pub limit: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct ListNovelsResponse {
    pub items: Vec<NovelRow>,
    pub total: i64,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct CreateNovelBody {
    #[serde(default)]
    pub chapter_index: Option<i32>,
    #[serde(default)]
    pub reel: Option<String>,
    #[serde(default)]
    pub chapter: Option<String>,
    #[serde(default)]
    pub chapter_data: Option<String>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct PatchNovelBody {
    #[serde(default)]
    pub chapter_index: Option<Value>,
    #[serde(default)]
    pub reel: Option<Value>,
    #[serde(default)]
    pub chapter: Option<Value>,
    #[serde(default)]
    pub chapter_data: Option<Value>,
    #[serde(default)]
    pub event: Option<Value>,
    #[serde(default)]
    pub event_state: Option<Value>,
    #[serde(default)]
    pub error_reason: Option<Value>,
}
