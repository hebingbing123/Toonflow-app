//! SQL row shapes for script-domain tools.

use serde::Serialize;

#[derive(sqlx::FromRow, Serialize)]
pub(super) struct HarnessScriptRow {
    #[sqlx(rename = "numeric_id")]
    pub numeric_id: i32,
    pub name: Option<String>,
    pub content: Option<String>,
    pub extract_state: Option<i32>,
}

#[derive(sqlx::FromRow, Serialize)]
pub(super) struct HarnessNovelRow {
    #[sqlx(rename = "numeric_id")]
    pub numeric_id: i32,
    pub chapter_index: i32,
    pub chapter: String,
    pub chapter_data: String,
    pub event_state: i32,
}

#[derive(sqlx::FromRow, Serialize)]
pub(super) struct HarnessNovelEventRow {
    #[sqlx(rename = "numeric_id")]
    pub numeric_id: i32,
    pub name: String,
    pub detail: String,
}
