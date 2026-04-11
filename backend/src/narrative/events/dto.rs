//! 小说事件 HTTP API 的请求/响应类型。

use serde::{Deserialize, Deserializer, Serialize};
use serde_json::Value;
use uuid::Uuid;

#[derive(Debug, Serialize)]
pub struct EventWithChapters {
    pub id: Uuid,
    pub project_id: Uuid,
    pub legacy_id: i32,
    pub name: String,
    pub detail: String,
    pub create_time_ms: Option<i64>,
    pub chapter_indexes: Vec<i32>,
}

impl From<super::query::EventQueryRow> for EventWithChapters {
    fn from(row: super::query::EventQueryRow) -> Self {
        Self {
            id: row.id,
            project_id: row.project_id,
            legacy_id: row.legacy_id,
            name: row.name,
            detail: row.detail,
            create_time_ms: row.create_time_ms,
            chapter_indexes: row.chapter_indexes,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct ListNovelEventsQuery {
    #[serde(default)]
    pub search: Option<String>,
    #[serde(default)]
    pub page: Option<u32>,
    #[serde(default)]
    pub limit: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct ListNovelEventsResponse {
    pub items: Vec<EventWithChapters>,
    pub total: i64,
}

#[derive(Debug, Deserialize, Default)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CreateNovelEventBody {
    pub name: String,
    #[serde(default)]
    pub detail: Option<String>,
    #[serde(default)]
    pub chapter_ids: Vec<i32>, // legacy novel ids to associate
}

fn deserialize_some_or_null<'de, D>(deserializer: D) -> Result<Option<Value>, D::Error>
where
    D: Deserializer<'de>,
{
    let v = Value::deserialize(deserializer)?;
    // Explicit null becomes Some(Value::Null), any other value is Some(v)
    Ok(Some(v))
}

fn default_none<T>() -> Option<T> {
    None
}

#[derive(Debug, Deserialize, Default)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct UpdateNovelEventBody {
    #[serde(default = "default_none")]
    pub name: Option<String>,
    #[serde(
        default = "default_none",
        deserialize_with = "deserialize_some_or_null"
    )]
    pub detail: Option<Value>, // null to clear, string to set, missing = don't change
    #[serde(default = "default_none")]
    pub chapter_ids: Option<Vec<i32>>, // if provided, replaces all associations
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BatchDeleteEventsBody {
    pub ids: Vec<i32>,
}

#[derive(Debug, Serialize)]
pub struct BatchDeleteEventsResponse {
    pub message: &'static str,
}

/// Legacy POST route matching old API shape.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct LegacyGetEventsBody {
    pub(crate) project_id: i32,
    pub(crate) page: u32,
    pub(crate) limit: u32,
    #[serde(default)]
    pub(crate) search: Option<String>,
}
