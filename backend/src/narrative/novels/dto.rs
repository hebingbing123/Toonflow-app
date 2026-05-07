//! 项目范围的小说 HTTP 类型和行映射。

use serde::{Deserialize, Deserializer, Serialize};
use serde_json::Value;
use utoipa::ToSchema;

/// PATCH JSON: distinguish **omitted** field (`None`) from explicit **`null`** (`Some(Null)`).
fn deserialize_patch_field_value<'de, D>(deserializer: D) -> Result<Option<Value>, D::Error>
where
    D: Deserializer<'de>,
{
    let v = Value::deserialize(deserializer)?;
    Ok(Some(v))
}
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow, Serialize)]
pub struct NovelRow {
    pub id: Uuid,
    #[serde(rename = "numeric_id")]
    #[sqlx(rename = "numeric_id")]
    pub numeric_id: i32,
    pub chapter_index: i32,
    pub reel: Option<String>,
    pub chapter: String,
    pub chapter_data: String,
    pub event: Option<String>,
    pub event_state: i32,
    pub error_reason: Option<String>,
    pub create_time_ms: Option<i64>,
    pub intake_source: Option<String>,
    pub intake_source_url: Option<String>,
    pub intake_status: Option<String>,
    pub intake_note: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct ListNovelsQuery {
    #[serde(default)]
    pub search: Option<String>,
    #[serde(default)]
    pub intake_status: Option<String>,
    #[serde(default)]
    pub intake_source: Option<String>,
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
    #[serde(default)]
    pub intake_source: Option<String>,
    #[serde(default)]
    pub intake_source_url: Option<String>,
    #[serde(default)]
    pub intake_status: Option<String>,
    #[serde(default)]
    pub intake_note: Option<String>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct PatchNovelBody {
    #[serde(default, deserialize_with = "deserialize_patch_field_value")]
    pub chapter_index: Option<Value>,
    #[serde(default, deserialize_with = "deserialize_patch_field_value")]
    pub reel: Option<Value>,
    #[serde(default, deserialize_with = "deserialize_patch_field_value")]
    pub chapter: Option<Value>,
    #[serde(default, deserialize_with = "deserialize_patch_field_value")]
    pub chapter_data: Option<Value>,
    #[serde(default, deserialize_with = "deserialize_patch_field_value")]
    pub event: Option<Value>,
    #[serde(default, deserialize_with = "deserialize_patch_field_value")]
    pub event_state: Option<Value>,
    #[serde(default, deserialize_with = "deserialize_patch_field_value")]
    pub error_reason: Option<Value>,
    #[serde(default, deserialize_with = "deserialize_patch_field_value")]
    pub intake_source: Option<Value>,
    #[serde(default, deserialize_with = "deserialize_patch_field_value")]
    pub intake_source_url: Option<Value>,
    #[serde(default, deserialize_with = "deserialize_patch_field_value")]
    pub intake_status: Option<Value>,
    #[serde(default, deserialize_with = "deserialize_patch_field_value")]
    pub intake_note: Option<Value>,
}

/// Body for **`POST …/novels/crawl-preview`** — server-side HTML fetch + text extraction (preview only).
#[derive(Debug, Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct NovelCrawlPreviewBody {
    pub url: String,
}

/// Response for **`POST …/novels/crawl-preview`**.
#[derive(Debug, Serialize, ToSchema)]
pub struct NovelCrawlPreviewResponse {
    pub title: String,
    pub body_text: String,
    pub mode: String,
    pub page_count: i32,
    pub chapter_url_count: i32,
    pub body_char_count: i32,
}

/// Body for **`POST …/novels/crawl-import`** — server-side crawl + parse + import.
#[derive(Debug, Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct NovelCrawlImportBody {
    pub url: String,
    pub intake_status: String,
    #[serde(default)]
    pub intake_note: Option<String>,
}

/// Response for **`POST …/novels/crawl-import`**.
#[derive(Debug, Serialize, ToSchema)]
pub struct NovelCrawlImportResponse {
    pub title: String,
    pub mode: String,
    pub page_count: i32,
    pub chapter_url_count: i32,
    pub body_char_count: i32,
    pub chapters_created: i32,
    pub quality_warnings: Vec<String>,
}
