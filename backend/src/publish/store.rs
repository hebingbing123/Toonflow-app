//! Postgres access for publish tables.

use chrono::{DateTime, Utc};
use serde_json::{json, Value};
use sqlx::types::Json;
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::error::ApiError;

use super::types::{
    CreatePublishDraftBody, CreatePublishJobBody, CreatePublishProfileBody, PatchPublishDraftBody,
    PatchPublishProfileBody, PublishAttemptAuditRow, PublishDraftRow, PublishJobRow,
    PublishMetricSyncCursorRow, PublishPerformanceAlertRow, PublishProfileRow, PublishTargetInput,
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

pub(crate) async fn list_attempt_audit(
    pool: &PgPool,
    project_id: Uuid,
    owner_user_id: Uuid,
    draft_id: Option<Uuid>,
    job_id: Option<Uuid>,
    limit: i64,
) -> Result<Vec<PublishAttemptAuditRow>, ApiError> {
    let capped_limit = limit.clamp(1, 200);
    sqlx::query_as::<_, PublishAttemptAuditRow>(
        r#"
        SELECT
          a.id,
          a.job_id,
          j.draft_id,
          a.target_id,
          t.platform_id,
          a.attempt_no,
          a.status,
          a.detail,
          a.error_message,
          a.created_at
        FROM app_publish_attempt AS a
        INNER JOIN app_publish_job AS j ON j.id = a.job_id
        INNER JOIN app_publish_target AS t ON t.id = a.target_id
        WHERE j.project_id = $1
          AND j.owner_user_id = $2
          AND ($3::uuid IS NULL OR j.draft_id = $3)
          AND ($4::uuid IS NULL OR j.id = $4)
        ORDER BY a.created_at DESC
        LIMIT $5
        "#,
    )
    .bind(project_id)
    .bind(owner_user_id)
    .bind(draft_id)
    .bind(job_id)
    .bind(capped_limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn list_low_performance_alerts(
    pool: &PgPool,
    project_id: Uuid,
    owner_user_id: Uuid,
    views_lt: i64,
    completion_rate_lt: f64,
    limit: i64,
) -> Result<Vec<PublishPerformanceAlertRow>, ApiError> {
    let capped_limit = limit.clamp(1, 200);
    let capped_views = views_lt.max(0);
    let capped_cr = completion_rate_lt.clamp(0.0, 1.0);
    sqlx::query_as::<_, PublishPerformanceAlertRow>(
        r#"
        SELECT
          s.target_id,
          s.draft_id,
          s.platform_id,
          COALESCE(s.views, 0)::BIGINT AS views,
          COALESCE(s.likes, 0)::BIGINT AS likes,
          COALESCE(s.comments, 0)::BIGINT AS comments,
          COALESCE(s.shares, 0)::BIGINT AS shares,
          COALESCE(s.completion_rate, 0)::DOUBLE PRECISION AS completion_rate,
          s.synced_at
        FROM (
          SELECT DISTINCT ON (target_id)
            target_id, draft_id, platform_id, views, likes, comments, shares, completion_rate, synced_at
          FROM app_publish_performance_snapshot
          WHERE project_id = $1
          ORDER BY target_id, synced_at DESC
        ) AS s
        INNER JOIN app_publish_draft AS d ON d.id = s.draft_id
        INNER JOIN app_project AS p ON p.id = d.project_id
        WHERE p.owner_user_id = $2
          AND (
            COALESCE(s.views, 0) < $3
            OR COALESCE(s.completion_rate, 0)::DOUBLE PRECISION < $4
          )
        ORDER BY s.synced_at DESC
        LIMIT $5
        "#,
    )
    .bind(project_id)
    .bind(owner_user_id)
    .bind(capped_views)
    .bind(capped_cr)
    .bind(capped_limit)
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
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let draft_id = sqlx::query_scalar::<_, Uuid>(
        r#"
        SELECT draft_id
        FROM app_publish_job
        WHERE id = $1 AND project_id = $2 AND owner_user_id = $3
          AND status IN ('failed', 'cancelled', 'partial_failed')
        FOR UPDATE
        "#,
    )
    .bind(job_id)
    .bind(project_id)
    .bind(owner_user_id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(draft_id) = draft_id else {
        tx.rollback()
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        return Ok(false);
    };

    let targets = sqlx::query_as::<_, PublishTargetRow>(
        r#"
        SELECT id, draft_id, platform_id, automation_mode, serial_order, extra, created_at, updated_at
        FROM app_publish_target
        WHERE draft_id = $1
        ORDER BY serial_order ASC, created_at ASC
        "#,
    )
    .bind(draft_id)
    .fetch_all(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for target in &targets {
        let next_attempt_no: i32 = sqlx::query_scalar(
            r#"
            SELECT COALESCE(MAX(a.attempt_no), 0)::INT + 1
            FROM app_publish_attempt AS a
            WHERE a.job_id = $1 AND a.target_id = $2
            "#,
        )
        .bind(job_id)
        .bind(target.id)
        .fetch_one(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        sqlx::query(
            r#"
            INSERT INTO app_publish_attempt (job_id, target_id, attempt_no, status, detail)
            VALUES ($1, $2, $3, 'retrying', $4)
            "#,
        )
        .bind(job_id)
        .bind(target.id)
        .bind(next_attempt_no)
        .bind(Json(json!({
            "event": "manual_retry_requested",
            "platform_id": target.platform_id,
            "recorded_at": chrono::Utc::now().to_rfc3339(),
        })))
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    sqlx::query(
        r#"
        UPDATE app_publish_job SET
          status = 'queued',
          error_message = NULL,
          error_details = NULL,
          claimed_by = NULL,
          semi_auto_ack_at = NULL,
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(job_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(true)
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

pub(crate) struct PublishAttemptUpsert {
    pub(crate) target_id: Uuid,
    pub(crate) attempt_no: i32,
    pub(crate) status: String,
    pub(crate) detail: Value,
    pub(crate) error_message: Option<String>,
}

pub(crate) async fn insert_publish_attempts(
    pool: &PgPool,
    job_id: Uuid,
    attempts: &[PublishAttemptUpsert],
) -> Result<(), ApiError> {
    for attempt in attempts {
        sqlx::query(
            r#"
            INSERT INTO app_publish_attempt (
              job_id, target_id, attempt_no, status, detail, error_message
            )
            VALUES ($1, $2, $3, $4, $5, $6)
            "#,
        )
        .bind(job_id)
        .bind(attempt.target_id)
        .bind(attempt.attempt_no)
        .bind(attempt.status.as_str())
        .bind(Json(attempt.detail.clone()))
        .bind(attempt.error_message.as_deref())
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }
    Ok(())
}

pub(crate) async fn finalize_job_with_attempts(
    pool: &PgPool,
    job_id: Uuid,
    draft_id: Uuid,
    attempts: &[PublishAttemptUpsert],
) -> Result<(), ApiError> {
    let succeeded = attempts.iter().filter(|a| a.status == "succeeded").count();
    let failed = attempts.iter().filter(|a| a.status != "succeeded").count();
    let (final_status, final_error_message): (&str, Option<String>) = if failed == 0 {
        ("succeeded", None)
    } else if succeeded == 0 {
        ("failed", Some("all publish targets failed".to_string()))
    } else {
        (
            "partial_failed",
            Some(format!("{failed} publish targets failed")),
        )
    };

    clear_attempts_for_job(pool, job_id).await?;
    insert_publish_attempts(pool, job_id, attempts).await?;
    sqlx::query(
        r#"
        UPDATE app_publish_job SET
          status = $2,
          error_message = $3,
          error_details = NULL,
          claimed_by = NULL,
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(job_id)
    .bind(final_status)
    .bind(final_error_message.as_deref())
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for attempt in attempts {
        sqlx::query(
            r#"
            UPDATE app_publish_target
            SET
              extra = COALESCE(extra, '{}'::jsonb) || $2,
              updated_at = NOW()
            WHERE id = $1
            "#,
        )
        .bind(attempt.target_id)
        .bind(Json(json!({
            "last_publish_result": {
                "job_id": job_id,
                "attempt_no": attempt.attempt_no,
                "status": attempt.status,
                "error_message": attempt.error_message,
                "detail": attempt.detail,
                "updated_at": chrono::Utc::now().to_rfc3339(),
            }
        })))
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let maybe_external_video_id = attempt
            .detail
            .get("receipt")
            .and_then(|r| r.get("external_video_id"))
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());
        let platform_id = attempt
            .detail
            .get("platform_id")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string();
        let delivery_mode = attempt
            .detail
            .get("delivery_mode")
            .and_then(|v| v.as_str())
            .filter(|s| !s.trim().is_empty())
            .unwrap_or("unknown")
            .to_string();
        if attempt.status == "succeeded" && !platform_id.is_empty() {
            sqlx::query(
                r#"
                INSERT INTO app_publish_metric_sync_cursor (
                  project_id, target_id, platform_id, status, retry_count, metadata, last_synced_at, updated_at
                )
                SELECT d.project_id, t.id, t.platform_id, 'idle', 0, $2, NULL, NOW()
                FROM app_publish_target AS t
                INNER JOIN app_publish_draft AS d ON d.id = t.draft_id
                WHERE t.id = $1
                ON CONFLICT (project_id, target_id)
                DO UPDATE SET
                  platform_id = EXCLUDED.platform_id,
                  status = 'idle',
                  retry_count = 0,
                  next_retry_at = NULL,
                  last_error = NULL,
                  metadata = COALESCE(app_publish_metric_sync_cursor.metadata, '{}'::jsonb) || EXCLUDED.metadata,
                  updated_at = NOW()
                "#,
            )
            .bind(attempt.target_id)
            .bind(Json(json!({
                "last_publish_job_id": job_id,
                "external_video_id": maybe_external_video_id,
                "delivery_mode": delivery_mode,
                "last_publish_updated_at": chrono::Utc::now().to_rfc3339(),
            })))
            .execute(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        }
    }

    sqlx::query(
        r#"
        UPDATE app_publish_draft
        SET
          draft_status = CASE
            WHEN $2 = 'succeeded' THEN 'archived'
            ELSE draft_status
          END,
          metadata = COALESCE(metadata, '{}'::jsonb) || $3,
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(draft_id)
    .bind(final_status)
    .bind(Json(json!({
        "last_publish_result": {
            "job_id": job_id,
            "status": final_status,
            "error_message": final_error_message,
            "target_count": attempts.len(),
            "succeeded_count": succeeded,
            "failed_count": failed,
            "updated_at": chrono::Utc::now().to_rfc3339(),
        }
    })))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub(crate) async fn claim_next_metric_sync_cursor(
    pool: &PgPool,
) -> Result<Option<PublishMetricSyncCursorRow>, ApiError> {
    sqlx::query_as::<_, PublishMetricSyncCursorRow>(
        r#"
        WITH cte AS (
          SELECT id
          FROM app_publish_metric_sync_cursor
          WHERE status IN ('idle', 'retrying')
            AND (next_retry_at IS NULL OR next_retry_at <= NOW())
          ORDER BY COALESCE(last_synced_at, '1970-01-01'::timestamptz) ASC, updated_at ASC
          LIMIT 1
          FOR UPDATE SKIP LOCKED
        )
        UPDATE app_publish_metric_sync_cursor AS c
        SET status = 'running', updated_at = NOW()
        FROM cte
        WHERE c.id = cte.id
        RETURNING
          c.id, c.project_id, c.target_id, c.platform_id, c.cursor_token, c.status, c.retry_count,
          c.next_retry_at, c.last_error, c.metadata, c.last_synced_at, c.updated_at
        "#,
    )
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) async fn complete_metric_sync_cursor(
    pool: &PgPool,
    cursor_id: Uuid,
    metadata_patch: Value,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        UPDATE app_publish_metric_sync_cursor
        SET
          status = 'idle',
          retry_count = 0,
          next_retry_at = NULL,
          last_error = NULL,
          metadata = COALESCE(metadata, '{}'::jsonb) || $2,
          last_synced_at = NOW(),
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(cursor_id)
    .bind(Json(metadata_patch))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) async fn fail_metric_sync_cursor(
    pool: &PgPool,
    cursor_id: Uuid,
    retry_count: i32,
    message: &str,
) -> Result<(), ApiError> {
    let retry_delay_min = (retry_count.max(1) * 5).min(60);
    sqlx::query(
        r#"
        UPDATE app_publish_metric_sync_cursor
        SET
          status = 'retrying',
          retry_count = $2,
          next_retry_at = NOW() + make_interval(mins => $3),
          last_error = $4,
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(cursor_id)
    .bind(retry_count)
    .bind(retry_delay_min)
    .bind(message)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) struct PublishPerformanceSnapshotUpsert {
    pub(crate) project_id: Uuid,
    pub(crate) target_id: Uuid,
    pub(crate) platform_id: String,
    pub(crate) external_video_id: Option<String>,
    pub(crate) metric_window: String,
    pub(crate) views: i64,
    pub(crate) likes: i64,
    pub(crate) comments: i64,
    pub(crate) shares: i64,
    pub(crate) completion_rate: f64,
    pub(crate) raw_payload: Value,
}

pub(crate) async fn insert_publish_performance_snapshot(
    pool: &PgPool,
    upsert: &PublishPerformanceSnapshotUpsert,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        INSERT INTO app_publish_performance_snapshot (
          project_id, draft_id, target_id, platform_id, external_video_id, metric_window,
          views, likes, comments, shares, completion_rate, raw_payload, synced_at
        )
        SELECT
          $1, t.draft_id, $2, $3, $4, $5,
          $6, $7, $8, $9, $10, $11, NOW()
        FROM app_publish_target AS t
        WHERE t.id = $2
        "#,
    )
    .bind(upsert.project_id)
    .bind(upsert.target_id)
    .bind(upsert.platform_id.as_str())
    .bind(upsert.external_video_id.as_deref())
    .bind(upsert.metric_window.as_str())
    .bind(upsert.views)
    .bind(upsert.likes)
    .bind(upsert.comments)
    .bind(upsert.shares)
    .bind(upsert.completion_rate)
    .bind(Json(upsert.raw_payload.clone()))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}
