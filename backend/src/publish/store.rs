//! Postgres access for publish tables.

use chrono::{DateTime, Utc};
use serde_json::{json, Value};
use sqlx::types::Json;
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::error::ApiError;

use super::platform_registry::sandbox_publish_receipt;
use super::types::{
    CreatePublishDraftBody, CreatePublishJobBody, CreatePublishProfileBody, PatchPublishDraftBody,
    PatchPublishProfileBody, PublishDraftRow, PublishJobRow, PublishProfileRow, PublishTargetInput,
    PublishTargetRow,
};

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

pub(crate) async fn list_profiles(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<Vec<PublishProfileRow>, ApiError> {
    sqlx::query_as::<_, PublishProfileRow>(
        r#"
        SELECT id, project_id, name, target_market, default_platforms, title_style,
               tag_strategy, bio_template, schedule_strategy, metadata, created_at, updated_at
        FROM app_publish_profile
        WHERE project_id = $1
        ORDER BY name ASC
        "#,
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn insert_profile(
    pool: &PgPool,
    project_id: Uuid,
    body: &CreatePublishProfileBody,
) -> Result<PublishProfileRow, ApiError> {
    let row = sqlx::query_as::<_, PublishProfileRow>(
        r#"
        INSERT INTO app_publish_profile (
          project_id, name, target_market, default_platforms, title_style,
          tag_strategy, bio_template, schedule_strategy, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        RETURNING id, project_id, name, target_market, default_platforms, title_style,
                  tag_strategy, bio_template, schedule_strategy, metadata, created_at, updated_at
        "#,
    )
    .bind(project_id)
    .bind(body.name.trim())
    .bind(body.target_market.as_deref())
    .bind(body.default_platforms.as_ref())
    .bind(body.title_style.as_deref())
    .bind(body.tag_strategy.as_deref())
    .bind(body.bio_template.as_deref())
    .bind(body.schedule_strategy.as_deref())
    .bind(Json(body.metadata.clone()))
    .fetch_one(pool)
    .await
    .map_err(|e| {
        let msg = e.to_string();
        if msg.contains("app_publish_profile_name_unique") {
            ApiError::Conflict("profile name already exists for project".into())
        } else {
            ApiError::DatabaseError(msg)
        }
    })?;
    Ok(row)
}

pub(crate) async fn fetch_profile(
    pool: &PgPool,
    project_id: Uuid,
    profile_id: Uuid,
) -> Result<Option<PublishProfileRow>, ApiError> {
    sqlx::query_as::<_, PublishProfileRow>(
        r#"
        SELECT id, project_id, name, target_market, default_platforms, title_style,
               tag_strategy, bio_template, schedule_strategy, metadata, created_at, updated_at
        FROM app_publish_profile
        WHERE id = $1 AND project_id = $2
        "#,
    )
    .bind(profile_id)
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn patch_profile_row(
    pool: &PgPool,
    project_id: Uuid,
    profile_id: Uuid,
    body: &PatchPublishProfileBody,
) -> Result<Option<PublishProfileRow>, ApiError> {
    let existing = fetch_profile(pool, project_id, profile_id).await?;
    let Some(mut cur) = existing else {
        return Ok(None);
    };

    if let Some(ref name) = body.name {
        cur.name = name.trim().to_string();
    }
    if body.target_market.is_some() {
        cur.target_market = body.target_market.clone();
    }
    if body.default_platforms.is_some() {
        cur.default_platforms = body.default_platforms.clone();
    }
    if body.title_style.is_some() {
        cur.title_style = body.title_style.clone();
    }
    if body.tag_strategy.is_some() {
        cur.tag_strategy = body.tag_strategy.clone();
    }
    if body.bio_template.is_some() {
        cur.bio_template = body.bio_template.clone();
    }
    if body.schedule_strategy.is_some() {
        cur.schedule_strategy = body.schedule_strategy.clone();
    }
    if let Some(ref m) = body.metadata {
        cur.metadata = Json(m.clone());
    }

    let updated = sqlx::query_as::<_, PublishProfileRow>(
        r#"
        UPDATE app_publish_profile SET
          name = $3,
          target_market = $4,
          default_platforms = $5,
          title_style = $6,
          tag_strategy = $7,
          bio_template = $8,
          schedule_strategy = $9,
          metadata = $10,
          updated_at = NOW()
        WHERE id = $1 AND project_id = $2
        RETURNING id, project_id, name, target_market, default_platforms, title_style,
                  tag_strategy, bio_template, schedule_strategy, metadata, created_at, updated_at
        "#,
    )
    .bind(profile_id)
    .bind(project_id)
    .bind(&cur.name)
    .bind(&cur.target_market)
    .bind(&cur.default_platforms)
    .bind(&cur.title_style)
    .bind(&cur.tag_strategy)
    .bind(&cur.bio_template)
    .bind(&cur.schedule_strategy)
    .bind(&cur.metadata)
    .fetch_optional(pool)
    .await
    .map_err(|e| {
        let msg = e.to_string();
        if msg.contains("app_publish_profile_name_unique") {
            ApiError::Conflict("profile name already exists for project".into())
        } else {
            ApiError::DatabaseError(msg)
        }
    })?;
    Ok(updated)
}

pub(crate) async fn delete_profile(
    pool: &PgPool,
    project_id: Uuid,
    profile_id: Uuid,
) -> Result<bool, ApiError> {
    let res = sqlx::query(r#"DELETE FROM app_publish_profile WHERE id = $1 AND project_id = $2"#)
        .bind(profile_id)
        .bind(project_id)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(res.rows_affected() > 0)
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

pub(crate) async fn list_targets(
    pool: &PgPool,
    draft_id: Uuid,
) -> Result<Vec<PublishTargetRow>, ApiError> {
    sqlx::query_as::<_, PublishTargetRow>(
        r#"
        SELECT id, draft_id, platform_id, automation_mode, serial_order, extra, created_at, updated_at
        FROM app_publish_target
        WHERE draft_id = $1
        ORDER BY serial_order ASC, platform_id ASC
        "#,
    )
    .bind(draft_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn replace_targets_tx(
    tx: &mut Transaction<'_, Postgres>,
    draft_id: Uuid,
    targets: &[PublishTargetInput],
) -> Result<Vec<PublishTargetRow>, ApiError> {
    sqlx::query(r#"DELETE FROM app_publish_target WHERE draft_id = $1"#)
        .bind(draft_id)
        .execute(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut out = Vec::with_capacity(targets.len());
    for t in targets {
        let row = sqlx::query_as::<_, PublishTargetRow>(
            r#"
            INSERT INTO app_publish_target (draft_id, platform_id, automation_mode, serial_order, extra)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id, draft_id, platform_id, automation_mode, serial_order, extra, created_at, updated_at
            "#,
        )
        .bind(draft_id)
        .bind(t.platform_id.trim())
        .bind(t.automation_mode.trim())
        .bind(t.serial_order)
        .bind(Json(t.extra.clone()))
        .fetch_one(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        out.push(row);
    }
    Ok(out)
}

pub(crate) async fn replace_targets(
    pool: &PgPool,
    draft_id: Uuid,
    targets: &[PublishTargetInput],
) -> Result<Vec<PublishTargetRow>, ApiError> {
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let rows = replace_targets_tx(&mut tx, draft_id, targets).await?;
    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(rows)
}

pub(crate) async fn draft_has_semi_auto_target(
    pool: &PgPool,
    draft_id: Uuid,
) -> Result<bool, ApiError> {
    let v: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1 FROM app_publish_target
          WHERE draft_id = $1 AND automation_mode = 'semi_auto'
        )
        "#,
    )
    .bind(draft_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(v)
}

pub(crate) async fn insert_publish_job(
    pool: &PgPool,
    project_id: Uuid,
    draft_id: Uuid,
    owner_user_id: Uuid,
    body: &CreatePublishJobBody,
) -> Result<PublishJobRow, ApiError> {
    sqlx::query_as::<_, PublishJobRow>(
        r#"
        INSERT INTO app_publish_job (project_id, draft_id, owner_user_id, status, payload)
        VALUES ($1, $2, $3, 'queued', $4)
        RETURNING id, project_id, draft_id, owner_user_id, status, semi_auto_ack_at,
                  payload, error_message, error_details, claimed_by, created_at, updated_at
        "#,
    )
    .bind(project_id)
    .bind(draft_id)
    .bind(owner_user_id)
    .bind(Json(body.payload.clone()))
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn list_jobs(
    pool: &PgPool,
    project_id: Uuid,
    owner_user_id: Uuid,
) -> Result<Vec<PublishJobRow>, ApiError> {
    sqlx::query_as::<_, PublishJobRow>(
        r#"
        SELECT id, project_id, draft_id, owner_user_id, status, semi_auto_ack_at,
               payload, error_message, error_details, claimed_by, created_at, updated_at
        FROM app_publish_job
        WHERE project_id = $1 AND owner_user_id = $2
        ORDER BY created_at DESC
        LIMIT 100
        "#,
    )
    .bind(project_id)
    .bind(owner_user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn fetch_job_owned(
    pool: &PgPool,
    project_id: Uuid,
    job_id: Uuid,
    owner_user_id: Uuid,
) -> Result<Option<PublishJobRow>, ApiError> {
    sqlx::query_as::<_, PublishJobRow>(
        r#"
        SELECT id, project_id, draft_id, owner_user_id, status, semi_auto_ack_at,
               payload, error_message, error_details, claimed_by, created_at, updated_at
        FROM app_publish_job
        WHERE id = $1 AND project_id = $2 AND owner_user_id = $3
        "#,
    )
    .bind(job_id)
    .bind(project_id)
    .bind(owner_user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn cancel_job_if_non_terminal(
    pool: &PgPool,
    project_id: Uuid,
    job_id: Uuid,
    owner_user_id: Uuid,
) -> Result<bool, ApiError> {
    let res = sqlx::query(
        r#"
        UPDATE app_publish_job SET status = 'cancelled', updated_at = NOW()
        WHERE id = $1 AND project_id = $2 AND owner_user_id = $3
          AND status NOT IN ('succeeded', 'failed', 'cancelled', 'partial_failed')
        "#,
    )
    .bind(job_id)
    .bind(project_id)
    .bind(owner_user_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(res.rows_affected() > 0)
}

pub(crate) async fn retry_job_if_allowed(
    pool: &PgPool,
    project_id: Uuid,
    job_id: Uuid,
    owner_user_id: Uuid,
) -> Result<bool, ApiError> {
    let res = sqlx::query(
        r#"
        UPDATE app_publish_job SET
          status = 'queued',
          error_message = NULL,
          error_details = NULL,
          claimed_by = NULL,
          semi_auto_ack_at = NULL,
          updated_at = NOW()
        WHERE id = $1 AND project_id = $2 AND owner_user_id = $3
          AND status IN ('failed', 'cancelled', 'partial_failed')
        "#,
    )
    .bind(job_id)
    .bind(project_id)
    .bind(owner_user_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(res.rows_affected() > 0)
}

pub(crate) async fn confirm_semi_auto_job(
    pool: &PgPool,
    project_id: Uuid,
    job_id: Uuid,
    owner_user_id: Uuid,
) -> Result<bool, ApiError> {
    let res = sqlx::query(
        r#"
        UPDATE app_publish_job SET
          semi_auto_ack_at = NOW(),
          status = 'uploading',
          updated_at = NOW()
        WHERE id = $1 AND project_id = $2 AND owner_user_id = $3
          AND status = 'awaiting_confirmation'
        "#,
    )
    .bind(job_id)
    .bind(project_id)
    .bind(owner_user_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(res.rows_affected() > 0)
}

pub(crate) async fn claim_next_publish_job(
    pool: &PgPool,
    worker_id: &str,
) -> Result<Option<PublishJobRow>, sqlx::Error> {
    let mut tx = pool.begin().await?;
    let row = sqlx::query_as::<_, PublishJobRow>(
        r#"
        WITH cte AS (
          SELECT j.id
          FROM app_publish_job AS j
          INNER JOIN app_publish_draft AS d ON d.id = j.draft_id
          WHERE (
            j.status IN ('queued', 'retrying')
            OR (j.status = 'uploading' AND j.semi_auto_ack_at IS NOT NULL)
          )
          AND (d.scheduled_at IS NULL OR d.scheduled_at <= NOW())
          ORDER BY j.created_at ASC
          FOR UPDATE OF j SKIP LOCKED
          LIMIT 1
        )
        UPDATE app_publish_job AS j
        SET
          status = CASE
            WHEN j.status IN ('queued', 'retrying') THEN 'validating'
            ELSE j.status
          END,
          claimed_by = $1,
          updated_at = NOW()
        FROM cte
        WHERE j.id = cte.id
        RETURNING j.id, j.project_id, j.draft_id, j.owner_user_id, j.status, j.semi_auto_ack_at,
                  j.payload, j.error_message, j.error_details, j.claimed_by, j.created_at, j.updated_at
        "#,
    )
    .bind(worker_id)
    .fetch_optional(&mut *tx)
    .await?;
    tx.commit().await?;
    Ok(row)
}

pub(crate) async fn fail_publish_job_claim(
    pool: &PgPool,
    job_id: Uuid,
    message: &str,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        UPDATE app_publish_job SET
          status = 'failed',
          error_message = $2,
          error_details = NULL,
          claimed_by = NULL,
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(job_id)
    .bind(message)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) async fn await_publish_job_confirmation(
    pool: &PgPool,
    job_id: Uuid,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        UPDATE app_publish_job SET
          status = 'awaiting_confirmation',
          claimed_by = NULL,
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(job_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) async fn clear_attempts_for_job(pool: &PgPool, job_id: Uuid) -> Result<(), ApiError> {
    sqlx::query(r#"DELETE FROM app_publish_attempt WHERE job_id = $1"#)
        .bind(job_id)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) async fn insert_stub_success_attempts(
    pool: &PgPool,
    job_id: Uuid,
    targets: &[PublishTargetRow],
) -> Result<(), ApiError> {
    for (i, t) in targets.iter().enumerate() {
        sqlx::query(
            r#"
            INSERT INTO app_publish_attempt (job_id, target_id, attempt_no, status, detail)
            VALUES ($1, $2, $3, 'succeeded', $4)
            "#,
        )
        .bind(job_id)
        .bind(t.id)
        .bind(i as i32 + 1)
        .bind(Json(json!({
            "stub": true,
            "platform_id": t.platform_id,
            "receipt": sandbox_publish_receipt(job_id, &t.platform_id),
        })))
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }
    Ok(())
}

pub(crate) async fn finalize_job_stub_success(
    pool: &PgPool,
    job_id: Uuid,
    draft_id: Uuid,
    targets: &[PublishTargetRow],
) -> Result<(), ApiError> {
    clear_attempts_for_job(pool, job_id).await?;
    insert_stub_success_attempts(pool, job_id, targets).await?;
    sqlx::query(
        r#"
        UPDATE app_publish_job SET
          status = 'succeeded',
          error_message = NULL,
          error_details = NULL,
          claimed_by = NULL,
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(job_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let _ = draft_id; // reserved for future draft status projection / G 节回流
    Ok(())
}
