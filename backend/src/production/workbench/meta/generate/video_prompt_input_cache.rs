//! Metadata-backed input hash cache for **`generate-video-prompt`** (reduces redundant LLM work).

use serde_json::Value;
use sha2::{Digest, Sha256};
use sqlx::PgPool;

use crate::error::ApiError;

use super::handlers::{GenerateVideoPromptDiagnostics, GenerateVideoPromptResponse};

const HASH_KEY: &str = "videoPromptInputHash";
const PROMPT_KEY: &str = "cachedVideoPrompt";
const NEGATIVE_KEY: &str = "cachedVideoPromptNegative";
const OBSERVATION_KEY: &str = "cachedVideoPromptObservation";
const DURATION_KEY: &str = "cachedVideoPromptDuration";

#[derive(Debug, Clone)]
pub(crate) struct VideoPromptCacheHit {
    pub(crate) response: GenerateVideoPromptResponse,
}

pub(crate) fn compute_video_prompt_input_hash(
    description: Option<&str>,
    image_url: Option<&str>,
    storyboard_numeric_id: Option<i32>,
    script_numeric_id: i32,
    memory_budget_tier: &str,
    constraint_fingerprint: Option<&str>,
) -> String {
    let mut hasher = Sha256::new();
    hasher.update(script_numeric_id.to_string().as_bytes());
    hasher.update(b"\x00");
    if let Some(id) = storyboard_numeric_id {
        hasher.update(id.to_string().as_bytes());
        hasher.update(b"\x00");
    }
    hasher.update(description.unwrap_or("").trim().as_bytes());
    hasher.update(b"\x00");
    hasher.update(image_url.unwrap_or("").trim().as_bytes());
    hasher.update(b"\x00");
    hasher.update(memory_budget_tier.as_bytes());
    hasher.update(b"\x00");
    hasher.update(constraint_fingerprint.unwrap_or("").as_bytes());
    format!("{:x}", hasher.finalize())
}

pub(crate) async fn try_load_cached_video_prompt(
    pool: &PgPool,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
    input_hash: &str,
) -> Result<Option<VideoPromptCacheHit>, ApiError> {
    let row: Option<(Value,)> = sqlx::query_as(
        r#"
        SELECT COALESCE(sb.metadata, '{}'::jsonb) AS metadata
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        WHERE sc.numeric_id = $1
          AND sb.numeric_id = $2
        "#,
    )
    .bind(script_numeric_id)
    .bind(storyboard_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some((metadata,)) = row else {
        return Ok(None);
    };
    let short_video = metadata.get("shortVideo");
    let stored_hash = short_video
        .and_then(|v| v.get(HASH_KEY))
        .and_then(|v| v.as_str())
        .unwrap_or("");
    if stored_hash != input_hash {
        return Ok(None);
    }
    let prompt = short_video
        .and_then(|v| v.get(PROMPT_KEY))
        .and_then(|v| v.as_str())
        .map(str::trim)
        .filter(|s| !s.is_empty());
    let Some(prompt) = prompt else {
        return Ok(None);
    };
    let negative_prompt = short_video
        .and_then(|v| v.get(NEGATIVE_KEY))
        .and_then(|v| v.as_str())
        .map(str::to_string);
    let observation_note = short_video
        .and_then(|v| v.get(OBSERVATION_KEY))
        .and_then(|v| v.as_str())
        .map(str::to_string);
    let duration = short_video
        .and_then(|v| v.get(DURATION_KEY))
        .and_then(|v| v.as_i64())
        .unwrap_or(5) as i32;
    Ok(Some(VideoPromptCacheHit {
        response: GenerateVideoPromptResponse {
            prompt: prompt.to_string(),
            negative_prompt,
            observation_note,
            diagnostics: GenerateVideoPromptDiagnostics {
                memory_optimization_applied: true,
                memory_budget_tier: "cached".into(),
                ..Default::default()
            },
            model: "runway-gen-2".to_string(),
            duration,
        },
    }))
}

pub(crate) async fn persist_video_prompt_cache(
    pool: &PgPool,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
    input_hash: &str,
    response: &GenerateVideoPromptResponse,
) -> Result<(), ApiError> {
    let patch = serde_json::json!({
        HASH_KEY: input_hash,
        PROMPT_KEY: response.prompt,
        NEGATIVE_KEY: response.negative_prompt,
        OBSERVATION_KEY: response.observation_note,
        DURATION_KEY: response.duration,
    });
    sqlx::query(
        r#"
        UPDATE app_storyboard sb
        SET metadata = jsonb_set(
              jsonb_set(COALESCE(sb.metadata, '{}'::jsonb), '{shortVideo}', COALESCE(sb.metadata->'shortVideo', '{}'::jsonb), true),
              '{shortVideo}',
              COALESCE(sb.metadata->'shortVideo', '{}'::jsonb) || $3::jsonb,
              true
            ),
            updated_at = NOW()
        FROM app_script sc
        WHERE sb.script_id = sc.id
          AND sc.numeric_id = $1
          AND sb.numeric_id = $2
        "#,
    )
    .bind(script_numeric_id)
    .bind(storyboard_numeric_id)
    .bind(patch)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}
