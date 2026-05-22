//! Resumable whole-book import: batch chapter upsert with server-side session + dedupe.

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use std::collections::HashSet;

use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, validate_enum, ApiError};
use crate::projects::routes::common::require_project_write_scope;
use crate::state::AppState;

use super::super::dto::{
    WholeBookImportBody, WholeBookImportResponse, WholeBookImportSessionQuery,
    WholeBookImportSessionResponse,
};
use super::super::ADV_LOCK_NOVEL_NUMERIC;
use super::create::build_novel_intake_metadata;
use super::list::{normalize_intake_source, trim_opt};

const MAX_CHAPTERS_PER_REQUEST: usize = 50;
const MAX_CONTENT_HASH_LEN: usize = 128;
const MAX_TOTAL_CHAPTERS: i32 = 5000;

#[derive(Debug, sqlx::FromRow)]
struct SessionRow {
    content_hash: String,
    source_display_name: String,
    batch_tag: String,
    next_list_index: i32,
    total_chapters: i32,
    updated_at_ms: i64,
}

pub(crate) fn whole_book_chapter_dedupe_key(chapter_index: i32, chapter_title: &str) -> String {
    format!("{}::{}", chapter_index, chapter_title.trim().to_lowercase())
}

fn merge_intake_note(base: Option<&str>, batch_tag: &str) -> String {
    match base.map(str::trim).filter(|s| !s.is_empty()) {
        Some(note) if note.contains(batch_tag) => note.to_string(),
        Some(note) => format!("{note}; {batch_tag}"),
        None => batch_tag.to_string(),
    }
}

fn validate_content_hash(raw: &str) -> Result<(), ApiError> {
    let t = raw.trim();
    if t.is_empty() || t.len() > MAX_CONTENT_HASH_LEN {
        return Err(bad_request_i18n(
            "content_hash must be 1..=128 characters",
            "content_hash 长度须在 1–128 之间",
        ));
    }
    Ok(())
}

async fn load_existing_dedupe_keys(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<HashSet<String>, ApiError> {
    let rows: Vec<(i32, String)> = sqlx::query_as(
        r#"
        SELECT chapter_index, chapter
        FROM app_novel
        WHERE project_id = $1
        "#,
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(rows
        .into_iter()
        .map(|(idx, title)| whole_book_chapter_dedupe_key(idx, &title))
        .collect())
}

async fn fetch_session(
    pool: &PgPool,
    project_id: Uuid,
    content_hash: Option<&str>,
) -> Result<Option<SessionRow>, ApiError> {
    let row = if let Some(hash) = content_hash {
        sqlx::query_as::<_, SessionRow>(
            r#"
            SELECT content_hash, source_display_name, batch_tag, next_list_index,
                   total_chapters, updated_at_ms
            FROM app_novel_whole_book_import_session
            WHERE project_id = $1 AND content_hash = $2 AND status = 'in_progress'
            "#,
        )
        .bind(project_id)
        .bind(hash)
        .fetch_optional(pool)
        .await
    } else {
        sqlx::query_as::<_, SessionRow>(
            r#"
            SELECT content_hash, source_display_name, batch_tag, next_list_index,
                   total_chapters, updated_at_ms
            FROM app_novel_whole_book_import_session
            WHERE project_id = $1 AND status = 'in_progress'
            ORDER BY updated_at_ms DESC
            LIMIT 1
            "#,
        )
        .bind(project_id)
        .fetch_optional(pool)
        .await
    }
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(row)
}

async fn upsert_session(
    pool: &PgPool,
    project_id: Uuid,
    body: &WholeBookImportBody,
    batch_tag: &str,
    next_list_index: i32,
    status: &str,
) -> Result<(), ApiError> {
    let now_ms = chrono::Utc::now().timestamp_millis();
    sqlx::query(
        r#"
        INSERT INTO app_novel_whole_book_import_session (
          project_id, content_hash, source_display_name, batch_tag,
          next_list_index, total_chapters, intake_status, intake_source_url,
          intake_note_base, status, updated_at_ms, created_at_ms
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $11)
        ON CONFLICT (project_id, content_hash) DO UPDATE SET
          source_display_name = EXCLUDED.source_display_name,
          batch_tag = EXCLUDED.batch_tag,
          next_list_index = EXCLUDED.next_list_index,
          total_chapters = EXCLUDED.total_chapters,
          intake_status = EXCLUDED.intake_status,
          intake_source_url = EXCLUDED.intake_source_url,
          intake_note_base = EXCLUDED.intake_note_base,
          status = EXCLUDED.status,
          updated_at_ms = EXCLUDED.updated_at_ms
        "#,
    )
    .bind(project_id)
    .bind(body.content_hash.trim())
    .bind(
        body.source_display_name
            .as_deref()
            .filter(|s| !s.is_empty())
            .unwrap_or("whole_book"),
    )
    .bind(batch_tag)
    .bind(next_list_index)
    .bind(body.total_chapters)
    .bind(body.intake_status.trim())
    .bind(trim_opt(body.intake_source_url.clone()))
    .bind(trim_opt(body.intake_note.clone()))
    .bind(status)
    .bind(now_ms)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

async fn insert_one_chapter(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    project_id: Uuid,
    chapter_index: i32,
    chapter: &str,
    chapter_data: &str,
    metadata: &Value,
) -> Result<(), ApiError> {
    let next_numeric_id: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(numeric_id), 0) + 1
        FROM app_novel
        "#,
    )
    .fetch_one(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();
    sqlx::query(
        r#"
        INSERT INTO app_novel (
          project_id, numeric_id, chapter_index, reel, chapter, chapter_data,
          event, event_state, error_reason, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, NULL, $4, $5, NULL, 0, NULL, $6, $7)
        "#,
    )
    .bind(project_id)
    .bind(next_numeric_id)
    .bind(chapter_index)
    .bind(chapter)
    .bind(chapter_data)
    .bind(now_ms)
    .bind(metadata)
    .execute(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/novels/whole-book-import/session",
    operation_id = "getProjectNovelWholeBookImportSessionByProjectIdV1",
    tag = "novels",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("content_hash" = Option<String>, Query, description = "Optional content fingerprint; latest in-progress session if omitted")
    ),
    responses(
        (status = 200, description = "OK", body = WholeBookImportSessionResponse),
        (status = 404, description = "No active session", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_novel_whole_book_import_session(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
    Query(query): Query<WholeBookImportSessionQuery>,
) -> Result<Json<WholeBookImportSessionResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_write_scope(&state, uid, project_id).await?;

    let hash = query
        .content_hash
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty());
    let session = fetch_session(pool, project_id, hash).await?;
    let Some(row) = session else {
        return Err(ApiError::NotFound);
    };
    if row.next_list_index >= row.total_chapters {
        return Err(ApiError::NotFound);
    }
    Ok(Json(WholeBookImportSessionResponse {
        content_hash: row.content_hash,
        source_display_name: row.source_display_name,
        batch_tag: row.batch_tag,
        next_list_index: row.next_list_index,
        total_chapters: row.total_chapters,
        updated_at_ms: row.updated_at_ms,
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/novels/whole-book-import",
    operation_id = "postProjectNovelWholeBookImportByProjectIdV1",
    tag = "novels",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    request_body = WholeBookImportBody,
    responses(
        (status = 200, description = "OK", body = WholeBookImportResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_novel_whole_book_import(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
    Json(body): Json<WholeBookImportBody>,
) -> Result<Json<WholeBookImportResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_write_scope(&state, uid, project_id).await?;

    validate_content_hash(&body.content_hash)?;
    if body.total_chapters <= 0 || body.total_chapters > MAX_TOTAL_CHAPTERS {
        return Err(bad_request_i18n(
            "total_chapters must be between 1 and 5000",
            "total_chapters 须在 1–5000 之间",
        ));
    }
    if body.chapters.is_empty() || body.chapters.len() > MAX_CHAPTERS_PER_REQUEST {
        return Err(bad_request_i18n(
            &format!("chapters must contain 1..={MAX_CHAPTERS_PER_REQUEST} items"),
            &format!("chapters 每批须包含 1–{MAX_CHAPTERS_PER_REQUEST} 章"),
        ));
    }
    validate_enum(
        body.intake_status.trim(),
        &["draft", "pending_review", "admitted", "rejected"],
        "intake_status",
    )?;

    let content_hash = body.content_hash.trim().to_string();
    let existing_session = fetch_session(pool, project_id, Some(&content_hash)).await?;
    let start_list_index = body.start_list_index.unwrap_or(0);
    if let Some(ref session) = existing_session {
        if start_list_index != session.next_list_index {
            return Err(bad_request_i18n(
                "start_list_index does not match server session progress",
                "start_list_index 与服务端导入进度不一致",
            ));
        }
        if body.total_chapters != session.total_chapters {
            return Err(bad_request_i18n(
                "total_chapters does not match server session",
                "total_chapters 与服务端会话不一致",
            ));
        }
    } else if start_list_index != 0 {
        return Err(bad_request_i18n(
            "start_list_index must be 0 for a new import session",
            "新导入会话的 start_list_index 必须为 0",
        ));
    }

    let batch_tag = body
        .batch_tag
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .or_else(|| existing_session.as_ref().map(|s| s.batch_tag.clone()))
        .unwrap_or_else(|| format!("whole_book_batch:{}", chrono::Utc::now().timestamp_millis()));

    let intake_note = merge_intake_note(body.intake_note.as_deref(), &batch_tag);
    let intake_source = normalize_intake_source("whole_book_import")?;
    let metadata = build_novel_intake_metadata(
        Some(intake_source),
        trim_opt(body.intake_source_url.clone()),
        Some(body.intake_status.trim().to_string()),
        Some(intake_note),
    );

    let mut dedupe_keys = load_existing_dedupe_keys(pool, project_id).await?;
    let mut imported = 0i32;
    let mut skipped_existing = 0i32;
    let mut list_index = start_list_index;
    let mut failed_at_list_index: Option<i32> = None;

    for (offset, item) in body.chapters.iter().enumerate() {
        let expected_index = start_list_index + offset as i32;
        if expected_index >= body.total_chapters {
            return Err(bad_request_i18n(
                "chapter batch exceeds total_chapters",
                "章节批次超出 total_chapters",
            ));
        }
        if item.chapter.trim().is_empty() {
            return Err(bad_request_i18n(
                &format!("chapter title empty at list index {expected_index}"),
                &format!("第 {expected_index} 章标题为空"),
            ));
        }
        if item.chapter_data.trim().is_empty() {
            return Err(bad_request_i18n(
                &format!("chapter body empty at list index {expected_index}"),
                &format!("第 {expected_index} 章正文为空"),
            ));
        }

        let dedupe_key = whole_book_chapter_dedupe_key(item.chapter_index, &item.chapter);

        if dedupe_keys.contains(&dedupe_key) {
            skipped_existing += 1;
            list_index = expected_index + 1;
            continue;
        }

        let mut tx = pool
            .begin()
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        sqlx::query("SELECT pg_advisory_xact_lock($1)")
            .bind(ADV_LOCK_NOVEL_NUMERIC)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        if insert_one_chapter(
            &mut tx,
            project_id,
            item.chapter_index,
            item.chapter.trim(),
            item.chapter_data.trim(),
            &metadata,
        )
        .await
        .is_err()
        {
            failed_at_list_index = Some(expected_index);
            list_index = expected_index;
            break;
        }

        tx.commit()
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        dedupe_keys.insert(dedupe_key);
        imported += 1;
        list_index = expected_index + 1;
    }

    let completed = failed_at_list_index.is_none() && list_index >= body.total_chapters;
    let status = if completed {
        "completed"
    } else {
        "in_progress"
    };
    upsert_session(pool, project_id, &body, &batch_tag, list_index, status).await?;

    let can_resume = failed_at_list_index.is_some() || list_index < body.total_chapters;

    Ok(Json(WholeBookImportResponse {
        imported,
        skipped_existing,
        next_list_index: list_index,
        total_chapters: body.total_chapters,
        batch_tag,
        content_hash,
        completed,
        can_resume,
        failed_at_list_index,
    }))
}

#[cfg(test)]
mod tests {
    use super::whole_book_chapter_dedupe_key;

    #[test]
    fn dedupe_key_normalizes_title_case() {
        assert_eq!(
            whole_book_chapter_dedupe_key(1, "  Chapter One  "),
            whole_book_chapter_dedupe_key(1, "chapter one")
        );
    }
}
