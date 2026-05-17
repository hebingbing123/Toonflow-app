//! Postgres-backed **`app_video_prompt_cache`** for **`generate-video-prompt`**.

use chrono::{DateTime, Utc};
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use crate::error::ApiError;

use super::handlers::{GenerateVideoPromptDiagnostics, GenerateVideoPromptResponse};

#[derive(Debug, FromRow)]
struct VideoPromptCacheRow {
    id: Uuid,
    prompt: String,
    negative_prompt: Option<String>,
    observation_note: Option<String>,
    model: String,
    duration_seconds: i32,
}

pub(crate) async fn try_load_table_video_prompt(
    pool: &PgPool,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
    input_hash: &str,
) -> Result<Option<GenerateVideoPromptResponse>, ApiError> {
    let row = sqlx::query_as::<_, VideoPromptCacheRow>(
        r#"
        SELECT id, prompt, negative_prompt, observation_note, model, duration_seconds
        FROM app_video_prompt_cache
        WHERE script_numeric_id = $1
          AND storyboard_numeric_id = $2
          AND input_hash = $3
        "#,
    )
    .bind(script_numeric_id)
    .bind(storyboard_numeric_id)
    .bind(input_hash)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(row) = row else {
        return Ok(None);
    };

    sqlx::query(
        r#"
        UPDATE app_video_prompt_cache
        SET last_used_at = now(), use_count = use_count + 1, updated_at = now()
        WHERE id = $1
        "#,
    )
    .bind(row.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Some(GenerateVideoPromptResponse {
        prompt: row.prompt,
        negative_prompt: row.negative_prompt,
        observation_note: row.observation_note,
        diagnostics: GenerateVideoPromptDiagnostics {
            memory_optimization_applied: true,
            memory_budget_tier: "table_cache".into(),
            ..Default::default()
        },
        model: row.model,
        duration: row.duration_seconds,
    }))
}

pub(crate) async fn upsert_table_video_prompt(
    pool: &PgPool,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
    input_hash: &str,
    response: &GenerateVideoPromptResponse,
) -> Result<(), ApiError> {
    let _now: DateTime<Utc> = Utc::now();
    sqlx::query(
        r#"
        INSERT INTO app_video_prompt_cache (
          script_numeric_id,
          storyboard_numeric_id,
          input_hash,
          prompt,
          negative_prompt,
          observation_note,
          model,
          duration_seconds
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (script_numeric_id, storyboard_numeric_id, input_hash) DO UPDATE
        SET prompt = EXCLUDED.prompt,
            negative_prompt = EXCLUDED.negative_prompt,
            observation_note = EXCLUDED.observation_note,
            model = EXCLUDED.model,
            duration_seconds = EXCLUDED.duration_seconds,
            last_used_at = now(),
            updated_at = now(),
            use_count = app_video_prompt_cache.use_count + 1
        "#,
    )
    .bind(script_numeric_id)
    .bind(storyboard_numeric_id)
    .bind(input_hash)
    .bind(&response.prompt)
    .bind(&response.negative_prompt)
    .bind(&response.observation_note)
    .bind(&response.model)
    .bind(response.duration)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}
