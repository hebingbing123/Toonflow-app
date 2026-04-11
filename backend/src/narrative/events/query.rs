use serde::Serialize;
use sqlx::{FromRow, PgPool, Postgres, QueryBuilder};
use uuid::Uuid;

use crate::error::ApiError;

#[derive(Debug, FromRow)]
pub(super) struct EventQueryRow {
    pub(super) id: Uuid,
    pub(super) project_id: Uuid,
    pub(super) legacy_id: i32,
    pub(super) name: String,
    pub(super) detail: String,
    pub(super) create_time_ms: Option<i64>,
    pub(super) chapter_indexes: Vec<i32>,
}

#[derive(Debug, FromRow, Serialize)]
pub(super) struct LegacyEventRow {
    id: i32,
    #[serde(rename = "eventName")]
    event_name: String,
    detail: Option<String>,
    #[serde(rename = "createTime")]
    create_time: i64,
    chapters: Vec<i32>,
}

pub(super) fn search_ilike(raw: Option<String>) -> Option<String> {
    raw.and_then(|s| {
        let t = s.trim();
        if t.is_empty() {
            None
        } else {
            Some(format!("%{t}%"))
        }
    })
}

pub(super) async fn count_novel_events(
    pool: &PgPool,
    project_legacy_id: i32,
    uid: Uuid,
    search_pat: Option<&str>,
) -> Result<i64, ApiError> {
    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        "SELECT COUNT(DISTINCT e.id)::BIGINT
         FROM app_novel_event e
         INNER JOIN app_project p ON p.id = e.project_id
         WHERE p.legacy_id = ",
    );
    qb.push_bind(project_legacy_id);
    qb.push(" AND p.owner_user_id = ");
    qb.push_bind(uid);
    if let Some(pat) = search_pat {
        qb.push(" AND e.name ILIKE ");
        qb.push_bind(pat);
    }
    qb.build_query_scalar::<i64>()
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(super) async fn list_event_rows(
    pool: &PgPool,
    project_legacy_id: i32,
    uid: Uuid,
    limit: i64,
    offset: i64,
    search_pat: Option<&str>,
) -> Result<Vec<EventQueryRow>, ApiError> {
    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT 
            e.id as "id!",
            e.project_id as "project_id!",
            e.legacy_id as "legacy_id!",
            e.name as "name!",
            e.detail as "detail!",
            e.create_time_ms,
            COALESCE(
                ARRAY_AGG(n.chapter_index ORDER BY n.chapter_index) 
                FILTER (WHERE n.chapter_index IS NOT NULL),
                ARRAY[]::INTEGER[]
            ) as "chapter_indexes!: Vec<i32>"
        FROM app_novel_event e
        INNER JOIN app_project p ON p.id = e.project_id
        LEFT JOIN app_novel_event_chapter ec ON ec.event_id = e.id
        LEFT JOIN app_novel n ON n.id = ec.novel_id
        WHERE p.legacy_id = "#,
    );
    qb.push_bind(project_legacy_id);
    qb.push(" AND p.owner_user_id = ");
    qb.push_bind(uid);
    if let Some(pat) = search_pat {
        qb.push(" AND e.name ILIKE ");
        qb.push_bind(pat);
    }
    qb.push(
        " GROUP BY e.id, e.project_id, e.legacy_id, e.name, e.detail, e.create_time_ms
          ORDER BY e.create_time_ms DESC NULLS LAST, e.legacy_id DESC
          LIMIT ",
    );
    qb.push_bind(limit);
    qb.push(" OFFSET ");
    qb.push_bind(offset);

    qb.build_query_as::<EventQueryRow>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(super) async fn list_legacy_event_rows(
    pool: &PgPool,
    project_legacy_id: i32,
    uid: Uuid,
    limit: i64,
    offset: i64,
    search_pat: Option<&str>,
) -> Result<Vec<LegacyEventRow>, ApiError> {
    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT 
            e.legacy_id as "id!",
            e.name as "event_name!",
            e.detail,
            e.create_time_ms as "create_time!",
            COALESCE(
                ARRAY_AGG(n.chapter_index ORDER BY n.chapter_index) 
                FILTER (WHERE n.chapter_index IS NOT NULL),
                ARRAY[]::INTEGER[]
            ) as "chapters!: Vec<i32>"
        FROM app_novel_event e
        INNER JOIN app_project p ON p.id = e.project_id
        LEFT JOIN app_novel_event_chapter ec ON ec.event_id = e.id
        LEFT JOIN app_novel n ON n.id = ec.novel_id
        WHERE p.legacy_id = "#,
    );
    qb.push_bind(project_legacy_id);
    qb.push(" AND p.owner_user_id = ");
    qb.push_bind(uid);
    if let Some(pat) = search_pat {
        qb.push(" AND e.name ILIKE ");
        qb.push_bind(pat);
    }
    qb.push(
        " GROUP BY e.id, e.legacy_id, e.name, e.detail, e.create_time_ms
          ORDER BY e.create_time_ms DESC NULLS LAST, e.legacy_id DESC
          LIMIT ",
    );
    qb.push_bind(limit);
    qb.push(" OFFSET ");
    qb.push_bind(offset);

    qb.build_query_as::<LegacyEventRow>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
}
