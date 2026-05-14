//! Draft operations for publish store.

use chrono::{DateTime, Utc};
use serde_json::Value;
use sqlx::types::Json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::publish::types::{CreatePublishDraftBody, PatchPublishDraftBody, PublishDraftRow};

/// Half-open `[from, to)` UTC window used by `GET …/publish/drafts`.
pub(crate) type ScheduledDraftUtcWindow = (DateTime<Utc>, DateTime<Utc>);

fn merge_platform_block(existing: Option<&Value>, incoming: &Value) -> Value {
    match incoming {
        Value::Object(in_map) => {
            let mut base = existing
                .and_then(|v| v.as_object())
                .cloned()
                .unwrap_or_default();
            for (k, v) in in_map {
                base.insert(k.clone(), v.clone());
            }
            Value::Object(base)
        }
        _ => incoming.clone(),
    }
}

fn merge_publish_platform_copy(cur: &Value, fragment: &Value) -> Value {
    let mut root = cur.as_object().cloned().unwrap_or_default();
    if let Some(frag_obj) = fragment.as_object() {
        for (pid, incoming) in frag_obj {
            let merged = merge_platform_block(root.get(pid), incoming);
            root.insert(pid.clone(), merged);
        }
    }
    Value::Object(root)
}
pub(crate) async fn list_drafts(
    pool: &PgPool,
    project_id: Uuid,
    scheduled_window: Option<ScheduledDraftUtcWindow>,
) -> Result<Vec<PublishDraftRow>, ApiError> {
    match scheduled_window {
        None => sqlx::query_as::<_, PublishDraftRow>(
            r#"
        SELECT id, project_id, profile_id, script_id, video_asset_key, cover_asset_key,
               title, description, tags, platform_copy, scheduled_at, draft_status,
               metadata, created_at, updated_at
        FROM app_publish_draft
        WHERE project_id = $1
        ORDER BY updated_at DESC
        "#,
        )
        .bind(project_id)
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string())),
        Some((from, to_excl)) => sqlx::query_as::<_, PublishDraftRow>(
            r#"
        SELECT id, project_id, profile_id, script_id, video_asset_key, cover_asset_key,
               title, description, tags, platform_copy, scheduled_at, draft_status,
               metadata, created_at, updated_at
        FROM app_publish_draft
        WHERE project_id = $1
          AND scheduled_at IS NOT NULL
          AND scheduled_at >= $2
          AND scheduled_at < $3
        ORDER BY scheduled_at ASC
        "#,
        )
        .bind(project_id)
        .bind(from)
        .bind(to_excl)
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string())),
    }
}

pub(crate) async fn insert_draft(
    pool: &PgPool,
    project_id: Uuid,
    body: &CreatePublishDraftBody,
) -> Result<PublishDraftRow, ApiError> {
    sqlx::query_as::<_, PublishDraftRow>(
        r#"
        INSERT INTO app_publish_draft (
          project_id, profile_id, script_id, video_asset_key, cover_asset_key,
          title, description, tags, platform_copy, scheduled_at, draft_status, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        RETURNING id, project_id, profile_id, script_id, video_asset_key, cover_asset_key,
                  title, description, tags, platform_copy, scheduled_at, draft_status,
                  metadata, created_at, updated_at
        "#,
    )
    .bind(project_id)
    .bind(body.profile_id)
    .bind(body.script_id)
    .bind(body.video_asset_key.as_deref())
    .bind(body.cover_asset_key.as_deref())
    .bind(body.title.trim())
    .bind(body.description.trim())
    .bind(&body.tags)
    .bind(Json(body.platform_copy.clone()))
    .bind(body.scheduled_at)
    .bind(body.draft_status.trim())
    .bind(Json(body.metadata.clone()))
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn fetch_draft(
    pool: &PgPool,
    project_id: Uuid,
    draft_id: Uuid,
) -> Result<Option<PublishDraftRow>, ApiError> {
    sqlx::query_as::<_, PublishDraftRow>(
        r#"
        SELECT id, project_id, profile_id, script_id, video_asset_key, cover_asset_key,
               title, description, tags, platform_copy, scheduled_at, draft_status,
               metadata, created_at, updated_at
        FROM app_publish_draft
        WHERE id = $1 AND project_id = $2
        "#,
    )
    .bind(draft_id)
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn patch_draft_row(
    pool: &PgPool,
    project_id: Uuid,
    draft_id: Uuid,
    body: &PatchPublishDraftBody,
) -> Result<Option<PublishDraftRow>, ApiError> {
    let Some(mut cur) = fetch_draft(pool, project_id, draft_id).await? else {
        return Ok(None);
    };

    if body.profile_id.is_some() {
        cur.profile_id = body.profile_id;
    }
    if body.script_id.is_some() {
        cur.script_id = body.script_id;
    }
    if body.video_asset_key.is_some() {
        cur.video_asset_key = body.video_asset_key.clone();
    }
    if body.cover_asset_key.is_some() {
        cur.cover_asset_key = body.cover_asset_key.clone();
    }
    if let Some(ref t) = body.title {
        cur.title = t.trim().to_string();
    }
    if let Some(ref d) = body.description {
        cur.description = d.trim().to_string();
    }
    if let Some(ref tags) = body.tags {
        cur.tags.clone_from(tags);
    }
    if let Some(ref fragment) = body.platform_copy_fragment {
        cur.platform_copy = Json(merge_publish_platform_copy(&cur.platform_copy.0, fragment));
    }
    if let Some(ref pc) = body.platform_copy {
        cur.platform_copy = Json(pc.clone());
    }
    if body.scheduled_at.is_some() {
        cur.scheduled_at = body.scheduled_at;
    }
    if let Some(ref ds) = body.draft_status {
        cur.draft_status = ds.trim().to_string();
    }
    if let Some(ref m) = body.metadata {
        cur.metadata = Json(m.clone());
    }

    let updated = sqlx::query_as::<_, PublishDraftRow>(
        r#"
        UPDATE app_publish_draft SET
          profile_id = $3,
          script_id = $4,
          video_asset_key = $5,
          cover_asset_key = $6,
          title = $7,
          description = $8,
          tags = $9,
          platform_copy = $10,
          scheduled_at = $11,
          draft_status = $12,
          metadata = $13,
          updated_at = NOW()
        WHERE id = $1 AND project_id = $2
        RETURNING id, project_id, profile_id, script_id, video_asset_key, cover_asset_key,
                  title, description, tags, platform_copy, scheduled_at, draft_status,
                  metadata, created_at, updated_at
        "#,
    )
    .bind(draft_id)
    .bind(project_id)
    .bind(cur.profile_id)
    .bind(cur.script_id)
    .bind(&cur.video_asset_key)
    .bind(&cur.cover_asset_key)
    .bind(&cur.title)
    .bind(&cur.description)
    .bind(&cur.tags)
    .bind(&cur.platform_copy)
    .bind(cur.scheduled_at)
    .bind(&cur.draft_status)
    .bind(&cur.metadata)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(updated)
}

pub(crate) async fn delete_draft(
    pool: &PgPool,
    project_id: Uuid,
    draft_id: Uuid,
) -> Result<bool, ApiError> {
    let res = sqlx::query(r#"DELETE FROM app_publish_draft WHERE id = $1 AND project_id = $2"#)
        .bind(draft_id)
        .bind(project_id)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(res.rows_affected() > 0)
}

pub(crate) async fn merge_draft_platform_copy(
    pool: &PgPool,
    project_id: Uuid,
    draft_id: Uuid,
    fragment: &Value,
) -> Result<Option<PublishDraftRow>, ApiError> {
    let Some(cur) = fetch_draft(pool, project_id, draft_id).await? else {
        return Ok(None);
    };
    let merged = merge_publish_platform_copy(&cur.platform_copy.0, fragment);
    let updated = sqlx::query_as::<_, PublishDraftRow>(
        r#"
        UPDATE app_publish_draft SET
          platform_copy = $3,
          updated_at = NOW()
        WHERE id = $1 AND project_id = $2
        RETURNING id, project_id, profile_id, script_id, video_asset_key, cover_asset_key,
                  title, description, tags, platform_copy, scheduled_at, draft_status,
                  metadata, created_at, updated_at
        "#,
    )
    .bind(draft_id)
    .bind(project_id)
    .bind(Json(merged))
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(updated)
}

pub(crate) async fn batch_set_draft_scheduled_at(
    pool: &PgPool,
    project_id: Uuid,
    draft_ids: &[Uuid],
    scheduled_at: Option<DateTime<Utc>>,
) -> Result<i64, ApiError> {
    if draft_ids.is_empty() {
        return Ok(0);
    }
    let res = sqlx::query(
        r#"
        UPDATE app_publish_draft SET
          scheduled_at = $3,
          updated_at = NOW()
        WHERE project_id = $1 AND id = ANY($2::uuid[])
        "#,
    )
    .bind(project_id)
    .bind(draft_ids)
    .bind(scheduled_at)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(res.rows_affected() as i64)
}

/// P8: Batch archive drafts
pub(crate) async fn batch_archive_drafts(
    pool: &PgPool,
    project_id: Uuid,
    draft_ids: &[Uuid],
) -> Result<i64, ApiError> {
    if draft_ids.is_empty() {
        return Ok(0);
    }
    let res = sqlx::query(
        r#"
        UPDATE app_publish_draft SET
          draft_status = 'archived',
          updated_at = NOW()
        WHERE project_id = $1 AND id = ANY($2::uuid[])
          AND draft_status != 'archived'
        "#,
    )
    .bind(project_id)
    .bind(draft_ids)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(res.rows_affected() as i64)
}

/// P8: Fetch multiple drafts for batch validation
pub(crate) async fn fetch_drafts_by_ids(
    pool: &PgPool,
    project_id: Uuid,
    draft_ids: &[Uuid],
) -> Result<Vec<PublishDraftRow>, ApiError> {
    if draft_ids.is_empty() {
        return Ok(Vec::new());
    }
    sqlx::query_as::<_, PublishDraftRow>(
        r#"
        SELECT id, project_id, profile_id, script_id, video_asset_key, cover_asset_key,
               title, description, tags, platform_copy, scheduled_at, draft_status,
               metadata, created_at, updated_at
        FROM app_publish_draft
        WHERE project_id = $1 AND id = ANY($2::uuid[])
        ORDER BY updated_at DESC
        "#,
    )
    .bind(project_id)
    .bind(draft_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}
