//! Profile operations for publish store.

use sqlx::types::Json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::publish::types::{CreatePublishProfileBody, PatchPublishProfileBody, PublishProfileRow};

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
