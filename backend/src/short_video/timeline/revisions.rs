//! Timeline revision snapshots and restore (**NLE M4a**).

use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::{conflict_with_details_i18n, ApiError};
use crate::short_video::timeline::document::ProjectTimelineDocument;

pub const MAX_REVISIONS_PER_PROJECT: i64 = 20;

#[derive(Debug, sqlx::FromRow)]
pub struct TimelineRevisionListItem {
    pub revision: i32,
    pub created_at: DateTime<Utc>,
    pub created_by: Option<Uuid>,
    pub _schema_version: i32,
    pub timeline_json: serde_json::Value,
}

#[derive(Debug, Clone)]
pub struct TimelineRevisionSummary {
    pub revision: i32,
    pub created_at: DateTime<Utc>,
    pub created_by: Option<Uuid>,
    pub summary: String,
}

pub fn revision_summary_from_json(timeline_json: &serde_json::Value) -> String {
    let video = timeline_json
        .get("tracks")
        .and_then(|t| t.get("video"))
        .and_then(|v| v.as_array())
        .map(|a| a.len())
        .unwrap_or(0);
    let subs = timeline_json
        .get("tracks")
        .and_then(|t| t.get("subtitles"))
        .and_then(|v| v.as_array())
        .map(|a| a.len())
        .unwrap_or(0);
    format!("{video} clips, {subs} subtitles")
}

pub async fn list_timeline_revisions(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<Vec<TimelineRevisionSummary>, ApiError> {
    let rows: Vec<TimelineRevisionListItem> = sqlx::query_as(
        r#"
        SELECT revision, created_at, created_by, schema_version AS _schema_version, timeline_json
        FROM app_project_timeline_revision
        WHERE project_id = $1
        ORDER BY revision DESC
        LIMIT 20
        "#,
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(rows
        .into_iter()
        .map(|r| TimelineRevisionSummary {
            revision: r.revision,
            created_at: r.created_at,
            created_by: r.created_by,
            summary: revision_summary_from_json(&r.timeline_json),
        })
        .collect())
}

pub async fn load_revision_document(
    pool: &PgPool,
    project_id: Uuid,
    revision: i32,
) -> Result<ProjectTimelineDocument, ApiError> {
    let row: Option<(i32, serde_json::Value)> = sqlx::query_as(
        r#"
        SELECT schema_version, timeline_json
        FROM app_project_timeline_revision
        WHERE project_id = $1 AND revision = $2
        "#,
    )
    .bind(project_id)
    .bind(revision)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some((schema_version, timeline_json)) = row else {
        return Err(crate::error::bad_request_i18n(
            "revision not found",
            "未找到该历史版本",
        ));
    };

    Ok(crate::short_video::timeline::parse_timeline_document(
        schema_version,
        &timeline_json,
    ))
}

async fn insert_revision_snapshot(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    project_id: Uuid,
    revision: i32,
    doc: &ProjectTimelineDocument,
    created_by: Uuid,
) -> Result<(), ApiError> {
    let timeline_json = serde_json::to_value(doc)
        .map_err(|e| ApiError::DatabaseError(format!("timeline serialize: {e}")))?;
    sqlx::query(
        r#"
        INSERT INTO app_project_timeline_revision
          (project_id, revision, timeline_json, schema_version, created_by)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (project_id, revision) DO NOTHING
        "#,
    )
    .bind(project_id)
    .bind(revision)
    .bind(timeline_json)
    .bind(doc.schema_version)
    .bind(created_by)
    .execute(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

async fn prune_old_revisions(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    project_id: Uuid,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        DELETE FROM app_project_timeline_revision
        WHERE project_id = $1
          AND revision NOT IN (
            SELECT revision
            FROM app_project_timeline_revision
            WHERE project_id = $1
            ORDER BY revision DESC
            LIMIT $2
          )
        "#,
    )
    .bind(project_id)
    .bind(MAX_REVISIONS_PER_PROJECT)
    .execute(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

/// Persist timeline, bump revision, snapshot history.
pub async fn upsert_timeline_with_revision(
    pool: &PgPool,
    project_id: Uuid,
    doc: &ProjectTimelineDocument,
    created_by: Uuid,
    expected_revision: Option<i32>,
) -> Result<(DateTime<Utc>, i32), ApiError> {
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let current: Option<(i32, DateTime<Utc>)> = sqlx::query_as(
        r#"
        SELECT revision, updated_at
        FROM app_project_timeline
        WHERE project_id = $1
        FOR UPDATE
        "#,
    )
    .bind(project_id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let current_revision = current.as_ref().map(|(r, _)| *r).unwrap_or(0);

    if let Some(expected) = expected_revision {
        if expected != current_revision {
            return Err(conflict_with_details_i18n(
                "timeline revision mismatch",
                "时间线版本冲突",
                serde_json::json!({
                    "expectedRevision": expected,
                    "currentRevision": current_revision,
                }),
            ));
        }
    }

    let next_revision = current_revision + 1;
    let timeline_json = serde_json::to_value(doc)
        .map_err(|e| ApiError::DatabaseError(format!("timeline serialize: {e}")))?;

    let updated_at: DateTime<Utc> = if current.is_some() {
        sqlx::query_scalar(
            r#"
            UPDATE app_project_timeline
            SET schema_version = $2,
                timeline_json = $3,
                revision = $4,
                updated_at = NOW()
            WHERE project_id = $1
            RETURNING updated_at
            "#,
        )
        .bind(project_id)
        .bind(doc.schema_version)
        .bind(&timeline_json)
        .bind(next_revision)
        .fetch_one(&mut *tx)
        .await
    } else {
        sqlx::query_scalar(
            r#"
            INSERT INTO app_project_timeline
              (project_id, schema_version, timeline_json, revision, updated_at)
            VALUES ($1, $2, $3, $4, NOW())
            RETURNING updated_at
            "#,
        )
        .bind(project_id)
        .bind(doc.schema_version)
        .bind(&timeline_json)
        .bind(next_revision)
        .fetch_one(&mut *tx)
        .await
    }
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    insert_revision_snapshot(&mut tx, project_id, next_revision, doc, created_by).await?;
    prune_old_revisions(&mut tx, project_id).await?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((updated_at, next_revision))
}
