use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::error::ApiError;
use crate::scope;

use super::super::dto::{CreateStoryboardBody, StoryboardRow};
use super::super::ADV_LOCK_STORYBOARD_NUMERIC_ID;

pub(super) async fn fetch_storyboard_row(
    pool: &PgPool,
    id: Uuid,
) -> Result<StoryboardRow, ApiError> {
    sqlx::query_as::<_, StoryboardRow>(
        r#"
        SELECT
          id, script_id, numeric_id, numeric_script_id, prompt, file_path,
          duration, state, track_id, reason, track, video_desc,
          should_generate_image, numeric_project_id, flow_id, sb_index, create_time_ms
        FROM app_storyboard
        WHERE id = $1
        "#,
    )
    .bind(id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)
}

fn trim_opt_sb(s: Option<String>) -> Option<String> {
    s.and_then(|v| {
        let t = v.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_owned())
        }
    })
}

pub(super) async fn create_storyboard_locked(
    tx: &mut Transaction<'_, Postgres>,
    script_uuid: Uuid,
    project_numeric_id: i32,
    path_script_numeric_id: i32,
    body: CreateStoryboardBody,
) -> Result<StoryboardRow, ApiError> {
    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_STORYBOARD_NUMERIC_ID)
        .execute(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_numeric_id: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(numeric_id), 0) + 1
        FROM app_storyboard
        "#,
    )
    .fetch_one(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();
    let lsid = body.numeric_script_id.unwrap_or(path_script_numeric_id);
    let lpid = body.numeric_project_id.unwrap_or(project_numeric_id);

    sqlx::query_as::<_, StoryboardRow>(
        r#"
        INSERT INTO app_storyboard (
          script_id, numeric_id,
          numeric_script_id, numeric_project_id,
          prompt, file_path, duration, state, track_id, reason, track, video_desc,
          should_generate_image, flow_id, sb_index, create_time_ms, metadata
        )
        VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, '{}'::jsonb
        )
        RETURNING
          id, script_id, numeric_id, numeric_script_id, prompt, file_path,
          duration, state, track_id, reason, track, video_desc,
          should_generate_image, numeric_project_id, flow_id, sb_index, create_time_ms
        "#,
    )
    .bind(script_uuid)
    .bind(next_numeric_id)
    .bind(lsid)
    .bind(lpid)
    .bind(trim_opt_sb(body.prompt))
    .bind(trim_opt_sb(body.file_path))
    .bind(trim_opt_sb(body.duration))
    .bind(trim_opt_sb(body.state))
    .bind(body.track_id)
    .bind(trim_opt_sb(body.reason))
    .bind(trim_opt_sb(body.track))
    .bind(trim_opt_sb(body.video_desc))
    .bind(body.should_generate_image)
    .bind(body.flow_id)
    .bind(body.sb_index)
    .bind(now_ms)
    .fetch_one(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(super) async fn resolve_owned_storyboard_id(
    pool: &PgPool,
    uid: Uuid,
    project_id: Uuid,
    numeric_id: i32,
) -> Result<Uuid, ApiError> {
    let oid = scope::owned_storyboard_in_project(pool, uid, project_id, numeric_id)
        .await
        .map_err(|e| e.into_api_error())?;
    Ok(oid.storyboard_id)
}
