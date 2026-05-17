//! Persist cloned voice profiles on **`app_project.metadata.shortVideo.clonedVoices`**.

use chrono::Utc;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

use super::ClonedVoiceRef;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClonedVoiceRecord {
    pub custom_voice_id: String,
    pub display_name: String,
    pub provider: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub locale: Option<String>,
    pub created_at: String,
}

pub async fn append_cloned_voice(
    pool: &PgPool,
    project_id: Uuid,
    cloned: &ClonedVoiceRef,
) -> Result<(), ApiError> {
    let record = ClonedVoiceRecord {
        custom_voice_id: cloned.custom_voice_id.clone(),
        display_name: cloned.display_name.clone(),
        provider: cloned.provider.clone(),
        locale: cloned.locale.clone(),
        created_at: Utc::now().to_rfc3339(),
    };
    let record_json = serde_json::to_value(&record).map_err(|_| ApiError::Internal)?;
    sqlx::query(
        r#"
        UPDATE app_project
        SET metadata = jsonb_set(
              jsonb_set(
                COALESCE(metadata, '{}'::jsonb),
                '{shortVideo}',
                COALESCE(metadata->'shortVideo', '{}'::jsonb),
                true
              ),
              '{shortVideo,clonedVoices}',
              COALESCE(metadata #> '{shortVideo,clonedVoices}', '[]'::jsonb) || $2::jsonb,
              true
            ),
            updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(project_id)
    .bind(json!([record_json]))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

#[allow(dead_code)]
pub async fn list_cloned_voices(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<Vec<ClonedVoiceRecord>, ApiError> {
    let raw: Option<Value> = sqlx::query_scalar(
        r#"SELECT metadata #> '{shortVideo,clonedVoices}' FROM app_project WHERE id = $1"#,
    )
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some(Value::Array(items)) = raw else {
        return Ok(Vec::new());
    };
    let mut out = Vec::with_capacity(items.len());
    for item in items {
        if let Ok(rec) = serde_json::from_value::<ClonedVoiceRecord>(item) {
            out.push(rec);
        }
    }
    Ok(out)
}

pub fn mock_openai_voice_for_clone_id(custom_voice_id: &str) -> &'static str {
    const VOICES: [&str; 6] = ["alloy", "echo", "fable", "nova", "shimmer", "onyx"];
    let b = custom_voice_id.as_bytes();
    let idx = b.iter().map(|x| *x as usize).sum::<usize>() % VOICES.len();
    VOICES[idx]
}
