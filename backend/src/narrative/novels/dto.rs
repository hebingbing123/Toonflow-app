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

/// Optional per-request crawl auth override (merged with stored project config).
#[derive(Debug, Deserialize, Serialize, ToSchema, Default, Clone)]
#[serde(deny_unknown_fields)]
pub struct NovelCrawlAuthOverride {
    #[serde(default)]
    pub cookie: Option<String>,
    #[serde(default)]
    pub username: Option<String>,
    #[serde(default)]
    pub password: Option<String>,
}

/// Body for **`PUT …/novels/crawl-auth`** — persist encrypted crawl credentials.
#[derive(Debug, Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct NovelCrawlAuthPutBody {
    pub auth_mode: String,
    #[serde(default)]
    pub cookie: Option<String>,
    #[serde(default)]
    pub username: Option<String>,
    #[serde(default)]
    pub password: Option<String>,
    #[serde(default)]
    pub login_url: Option<String>,
    #[serde(default)]
    pub login_username_field: Option<String>,
    #[serde(default)]
    pub login_password_field: Option<String>,
}

/// Response for **`GET/PUT …/novels/crawl-auth`** (never returns secret values).
#[derive(Debug, Serialize, ToSchema)]
pub struct NovelCrawlAuthGetResponse {
    pub auth_mode: String,
    pub has_cookie: bool,
    pub has_username: bool,
    pub has_password: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub login_url: Option<String>,
    pub login_username_field: String,
    pub login_password_field: String,
    pub encryption_configured: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub updated_at: Option<String>,
}

/// Body for **`POST …/novels/crawl-preview`** — server-side HTML fetch + text extraction (preview only).
#[derive(Debug, Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct NovelCrawlPreviewBody {
    pub url: String,
    #[serde(default)]
    pub auth: Option<NovelCrawlAuthOverride>,
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
    #[serde(default)]
    pub auth: Option<NovelCrawlAuthOverride>,
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

/// Body for **`POST …/novels/crawl-import-batch`** — hosted crawl import for multiple URLs.
#[derive(Debug, Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct NovelCrawlImportBatchBody {
    pub urls: Vec<String>,
    pub intake_status: String,
    #[serde(default)]
    pub intake_note: Option<String>,
    #[serde(default)]
    pub auth: Option<NovelCrawlAuthOverride>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct NovelCrawlImportBatchItem {
    pub url: String,
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_code: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_message: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mode: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub page_count: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub chapter_url_count: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub body_char_count: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub chapters_created: Option<i32>,
    #[serde(default)]
    pub quality_warnings: Vec<String>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct NovelCrawlImportBatchResponse {
    pub total: i32,
    pub succeeded: i32,
    pub failed: i32,
    pub items: Vec<NovelCrawlImportBatchItem>,
}

#[derive(Debug, FromRow, Serialize, ToSchema)]
pub struct NovelIntakeSourceCount {
    pub intake_source: Option<String>,
    pub chapter_count: i64,
}

#[derive(Debug, FromRow, Serialize, ToSchema)]
pub struct NovelIntakeStatusCount {
    pub intake_status: Option<String>,
    pub chapter_count: i64,
}

#[derive(Debug, FromRow, Serialize, ToSchema)]
pub struct NovelCrawlJobStatusCount {
    pub status: String,
    pub job_count: i64,
}

#[derive(Debug, FromRow, Serialize, ToSchema)]
pub struct NovelCrawlAuditSampleRow {
    pub numeric_id: i32,
    pub intake_source_url: Option<String>,
    pub intake_note: Option<String>,
    pub create_time_ms: Option<i64>,
}

/// One chapter row in a whole-book import batch request.
#[derive(Debug, Deserialize, Serialize, ToSchema, Clone)]
#[serde(deny_unknown_fields)]
pub struct WholeBookImportChapterItem {
    pub chapter_index: i32,
    pub chapter: String,
    pub chapter_data: String,
}

/// Body for **`POST …/novels/whole-book-import`** — resumable batch chapter import.
#[derive(Debug, Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct WholeBookImportBody {
    pub content_hash: String,
    pub total_chapters: i32,
    pub chapters: Vec<WholeBookImportChapterItem>,
    pub intake_status: String,
    #[serde(default)]
    pub source_display_name: Option<String>,
    #[serde(default)]
    pub batch_tag: Option<String>,
    #[serde(default)]
    pub start_list_index: Option<i32>,
    #[serde(default)]
    pub intake_source_url: Option<String>,
    #[serde(default)]
    pub intake_note: Option<String>,
}

/// Response for **`POST …/novels/whole-book-import`**.
#[derive(Debug, Serialize, ToSchema)]
pub struct WholeBookImportResponse {
    pub imported: i32,
    pub skipped_existing: i32,
    pub next_list_index: i32,
    pub total_chapters: i32,
    pub batch_tag: String,
    pub content_hash: String,
    pub completed: bool,
    pub can_resume: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub failed_at_list_index: Option<i32>,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct WholeBookImportSessionQuery {
    #[serde(default)]
    pub content_hash: Option<String>,
}

/// Active whole-book import session for resume (Web + desktop).
#[derive(Debug, Serialize, ToSchema)]
pub struct WholeBookImportSessionResponse {
    pub content_hash: String,
    pub source_display_name: String,
    pub batch_tag: String,
    pub next_list_index: i32,
    pub total_chapters: i32,
    pub updated_at_ms: i64,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct NovelCrawlObservabilityResponse {
    pub total_chapters: i64,
    pub intake_sources: Vec<NovelIntakeSourceCount>,
    pub intake_statuses: Vec<NovelIntakeStatusCount>,
    pub recent_server_imports: Vec<NovelCrawlAuditSampleRow>,
    pub crawl_job_statuses: Vec<NovelCrawlJobStatusCount>,
}
