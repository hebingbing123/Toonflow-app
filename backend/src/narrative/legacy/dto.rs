//! Request/response types for legacy novel HTTP routes.

use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

use crate::narrative::novels::NovelRow;

use super::DEFAULT_GENERATE_EVENTS_CONCURRENCY;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct ProjectIdBody {
    pub(super) project_id: i32,
}

#[derive(Debug, Serialize)]
pub(super) struct LegacyNovelDataResponse {
    pub(super) data: Vec<NovelRow>,
}

#[derive(Debug, Serialize)]
pub(super) struct LegacyNovelIndexResponse {
    pub(super) data: Vec<NovelItem>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct GetNovelEventStateBody {
    pub(super) ids: Vec<i32>,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyNovelEventStateItem {
    /// **`app_novel.legacy_id`**.
    pub(super) id: i32,
    pub(super) event: Option<String>,
    pub(super) event_state: i32,
    pub(super) error_reason: Option<String>,
}

#[derive(Debug, Serialize)]
pub(super) struct LegacyNovelEventStateResponse {
    pub(super) data: Vec<LegacyNovelEventStateItem>,
}

#[derive(Debug, Serialize)]
pub(super) struct NovelItem {
    pub(super) id: i32,
    pub(super) index: i32,
    pub(super) chapter: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct BatchDeleteNovelsBody {
    pub(super) ids: Vec<i32>,
}

#[derive(Debug, Serialize)]
pub(super) struct BatchDeleteNovelsResponse {
    pub(super) message: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct GetNovelBody {
    pub(super) project_id: i32,
    pub(super) page: u32,
    pub(super) limit: u32,
    #[serde(default)]
    pub(super) search: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct LegacyNovelPageRow {
    /// **`app_novel.legacy_id`** (SQLite **`o_novel.id`**).
    pub(super) id: i32,
    pub(super) index: i32,
    pub(super) reel: Option<String>,
    pub(super) chapter: String,
    pub(super) chapter_data: String,
    pub(super) event: Option<String>,
    pub(super) event_state: i32,
    pub(super) error_reason: Option<String>,
}

#[derive(Debug, Serialize)]
pub(super) struct GetNovelResponse {
    pub(super) data: Vec<LegacyNovelPageRow>,
    pub(super) total: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct AddNovelItem {
    pub(super) index: i32,
    pub(super) reel: String,
    pub(super) chapter: String,
    #[serde(rename = "chapterData")]
    pub(super) chapter_data: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct AddNovelBody {
    pub(super) project_id: i32,
    pub(super) data: Vec<AddNovelItem>,
}

#[derive(Debug, Serialize)]
pub(super) struct NovelOkMessageResponse {
    pub(super) message: &'static str,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct DeleteSingleNovelBody {
    /// **`app_novel.legacy_id`**
    pub(super) id: i32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct UpdateNovelBody {
    pub(super) id: i32,
    pub(super) index: Value,
    pub(super) reel: String,
    pub(super) chapter: String,
    #[serde(rename = "chapterData")]
    pub(super) chapter_data: String,
    pub(super) event: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct GenerateNovelEventsBody {
    pub(super) project_id: i32,
    pub(super) novel_ids: Vec<i32>,
    #[serde(default = "default_generate_events_concurrency")]
    pub(super) concurrent_count: usize,
}

#[derive(Debug, Clone, FromRow)]
pub(super) struct NovelEventExtractionRow {
    pub(super) id: Uuid,
    pub(super) chapter_index: i32,
    pub(super) reel: Option<String>,
    pub(super) chapter: String,
    pub(super) chapter_data: String,
}

pub(super) fn default_generate_events_concurrency() -> usize {
    DEFAULT_GENERATE_EVENTS_CONCURRENCY
}
